FROM leader.telekube.local:5000/ae-editor:5.4.0-46.g640c57da1
COPY . /aesrc/vscode/
RUN set -ex \
    && /opt/continuum/anaconda/condabin/conda install -c defusco jsonmerge -y -n lab_launch \
    && rm -f /usr/bin/git /usr/bin/git-* \
    && for fname in /opt/continuum/anaconda/envs/lab_launch/bin/{git,git-*}; do \
           ln -s $fname /usr/bin/; \
       done \
    && cd /aesrc/vscode \
    && if [ ! -f code-server2.1698-vsc1.41.1-linux-x86_64.tar.gz ]; then \
          curl -O -L https://github.com/cdr/code-server/releases/download/2.1698/code-server2.1698-vsc1.41.1-linux-x86_64.tar.gz; \
       fi \
    && if [ ! -f ms-python-release.vsix ]; then \
          curl -O -L https://github.com/microsoft/vscode-python/releases/download/2020.2.64397/ms-python-release.vsix; \
       fi \
    && tar xfz code-server2.1698-vsc1.41.1-linux-x86_64.tar.gz \
    && chown -fR anaconda:anaconda code-server* \
    && mv code-server*/code-server \
          /opt/continuum/anaconda/envs/lab_launch/bin \
    && mv vscode /opt/continuum/.vscode \
    && chown -fR anaconda:anaconda /opt/continuum/.vscode \
    && su anaconda -c \
          "/opt/continuum/anaconda/envs/lab_launch/bin/code-server \
          --user-data-dir /opt/continuum/.vscode \
          --install-extension ms-python*.vsix" \
    && if [ ! -f /opt/continuum/scripts/start_user.sh ]; then \
           cp start_*.sh startup.sh build_condarc.py run_tool.py /opt/continuum/scripts; \
       else \
           cp start_vscode.sh /opt/continuum/scripts; \
           cp merge_vscode_settings.py /opt/continuum/scripts; \
       fi \
    && chmod +x /opt/continuum/scripts/*.sh \
    && chown anaconda:anaconda /opt/continuum/scripts/*.sh \
    && chown anaconda:anaconda /opt/continuum/scripts/merge_vscode_settings.py \
    && rm -f /aesrc/vscode/{*.tar.bz2,*.visx}
