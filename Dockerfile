FROM archlinux:latest

# Install basic dependencies
RUN echo '[multilib]' >> /etc/pacman.conf && \
    echo 'Include = /etc/pacman.d/mirrorlist' >> /etc/pacman.conf && \
    pacman --noconfirm -Syyu && \
    pacman --noconfirm -S base-devel git jupyterlab jupyter_console cuda npm wget

# Add a sudo user for AUR
RUN useradd -m -r -s /bin/bash aur && \
    passwd -d aur && \
    echo 'aur ALL=(ALL) ALL' > /etc/sudoers.d/aur && \
    mkdir -p /home/aur/.gnupg && \
    echo 'standard-resolver' > /home/aur/.gnupg/dirmngr.conf && \
    chown -R aur:aur /home/aur

# Build yay
RUN mkdir /build && \
    chown -R aur:aur /build && \
    cd /build && \
    sudo -u aur git clone --depth 1 https://aur.archlinux.org/yay-bin.git && \
    cd yay-bin && \
    sudo -u aur makepkg --noconfirm -si && \
    sudo -u aur yay --afterclean --removemake --nodiffmenu --nocleanmenu --save && \
    pacman -Qtdq | xargs -r pacman --noconfirm -Rcns && \
    rm -rf /home/aur/.cache && \
    rm -rf /build

# Install llvm90 and update LDCONFIG afterward
RUN sudo -u aur yay --noconfirm -S llvm90 && ldconfig

# Install clang90
RUN sudo -u aur yay --noconfirm -S clang90

# Install clasp and cando
RUN sudo -u aur yay --noconfirm -S clasp-cl-git

# Download the ambertools PKGBUILD
RUN cd /home/aur/.cache/yay && \
    sudo -u aur yay --noconfirm -G ambertools

# Copy the ambertools source archive then build ambertools
COPY --chown=aur:aur AmberTools20.tar.bz2 /home/aur/.cache/yay/ambertools/
RUN sudo -u aur yay --noconfirm -S ambertools

RUN rm -rf /home/aur/.cache/

# Install the JupyterLab extensions
RUN jupyter-labextension install @ijmbarr/jupyterlab_spellchecker \
     @jupyter-widgets/jupyterlab-manager cytoscape-clj ipysheet \
     jupyterlab-tabular-data-editor kekule-clj nglview-js-widgets@2.7.7 \
     ngl-clj resizable-box-clj

# Set up the environment
ARG APP_USER=app
ARG APP_UID=1000
ENV USER ${APP_USER}
ENV HOME /home/${APP_USER}
ENV PATH "$HOME/.local/bin:$PATH"
ENV SLIME_HOME "${HOME}/quicklisp/local-projects/slime"
ENV AMBERHOME /opt/amber/

# Create a user
RUN useradd --create-home --shell=/bin/bash --uid=${APP_UID} ${APP_USER}
COPY --chown=${APP_UID}:${APP_USER} home ${HOME}

WORKDIR ${HOME}
USER ${APP_USER}

# Install quicklisp
RUN wget --no-check-certificate https://beta.quicklisp.org/quicklisp.lisp && \
    sbcl --non-interactive --load quicklisp.lisp --eval "(quicklisp-quickstart:install)" && \
    rm quicklisp.lisp

# Use cando to add quickclasp
RUN cando --non-interactive

# Install SLIME
RUN git clone https://github.com/slime/slime.git ${HOME}/quicklisp/local-projects/slime

# Use SBCL to install needed packages and then install all of the kernels
RUN sbcl --non-interactive --eval "(ql:quickload '(:common-lisp-jupyter :kekule-clj :cytoscape-clj :nglview-cl))" --eval "(cl-jupyter:install :use-implementation t)"
RUN clasp --non-interactive --eval "(ql:quickload :common-lisp-jupyter)" --eval "(cl-jupyter:install :use-implementation t)"
RUN cando --non-interactive --eval "(ql:quickload :cando-jupyter)" --eval "(cando-jupyter:install)"

