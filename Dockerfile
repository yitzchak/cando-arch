FROM archlinux:latest

RUN echo '[multilib]' >> /etc/pacman.conf && \
    echo 'Include = /etc/pacman.d/mirrorlist' >> /etc/pacman.conf && \
    pacman --noconfirm -Syyu && \
    pacman --noconfirm -S base-devel git

RUN useradd -m -r -s /bin/bash aur && \
    passwd -d aur && \
    echo 'aur ALL=(ALL) ALL' > /etc/sudoers.d/aur && \
    mkdir -p /home/aur/.gnupg && \
    echo 'standard-resolver' > /home/aur/.gnupg/dirmngr.conf && \
    chown -R aur:aur /home/aur

RUN mkdir /build && \
    chown -R aur:aur /build && \
    cd /build && \
    sudo -u aur git clone --depth 1 https://aur.archlinux.org/yay-bin.git && \
    cd yay-bin && \
    sudo -u aur makepkg --noconfirm -si && \
    sudo -u aur yay --afterclean --removemake --save && \
    pacman -Qtdq | xargs -r pacman --noconfirm -Rcns && \
    rm -rf /home/aur/.cache && \
    rm -rf /build

RUN pacman --noconfirm -Syu jupyterlab jupyter_console

RUN sudo -u aur yay --noconfirm -S llvm90
RUN ldconfig
RUN sudo -u aur yay --noconfirm -S clang90
RUN sudo -u aur yay --noconfirm -S clasp-cl-git

RUN pacman --noconfirm -Syu npm wget

RUN jupyter-labextension install @ijmbarr/jupyterlab_spellchecker \
    @jupyter-widgets/jupyterlab-manager cytoscape-clj ipysheet \
    jupyterlab-tabular-data-editor kekule-clj nglview-js-widgets@2.7.7

ARG APP_USER=app
ARG APP_UID=1000
ENV USER ${APP_USER}
ENV HOME /home/${APP_USER}
ENV PATH "$HOME/.local/bin:$PATH"
ENV SLIME_HOME "${HOME}/quicklisp/local-projects/slime"

RUN useradd --create-home --shell=/bin/bash --uid=${APP_UID} ${APP_USER}
COPY --chown=${APP_UID}:${APP_USER} home ${HOME}

WORKDIR ${HOME}
USER ${APP_USER}

RUN wget --no-check-certificate https://beta.quicklisp.org/quicklisp.lisp && \
    sbcl --non-interactive --load quicklisp.lisp --eval "(quicklisp-quickstart:install)" && \
    rm quicklisp.lisp

RUN cando --non-interactive
RUN sbcl --non-interactive --eval "(ql:quickload :common-lisp-jupyter)" --eval "(cl-jupyter:install :use-implementation t)"
RUN clasp --non-interactive --eval "(ql:quickload :common-lisp-jupyter)" --eval "(cl-jupyter:install :use-implementation t)"
RUN cando --non-interactive --eval "(ql:quickload :cando-jupyter)" --eval "(cando-jupyter:install)"

#CMD ["/bin/bash"]

