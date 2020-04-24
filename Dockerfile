ARG WORKSPACE=leader.telekube.local:5000/ae-editor:5.4.0-46.g640c57da1
FROM $WORKSPACE
COPY . /aesrc/vscode/
RUN set -ex \
    && rm -f /usr/bin/git /usr/bin/git-* \
    && for fname in /opt/continuum/anaconda/envs/lab_launch/bin/{git,git-*}; do \
           ln -s $fname /usr/bin/; \
       done \
    && cd /aesrc/vscode \
    && if [ ! -f code-server-3.1.0-linux-x86_64.tar.gz ]; then \
          curl -O -L https://github.com/cdr/code-server/releases/download/3.1.1/code-server-3.1.1-linux-x86_64.tar.gz; \
       fi \
    && if [ ! -f ms-python-release.vsix ]; then \
          curl -O -L https://github.com/microsoft/vscode-python/releases/download/2020.4.74986/ms-python-release.vsix; \
       fi \
    && tar xfz code-server-3.1.1-linux-x86_64.tar.gz \
    && chown -fR anaconda:anaconda code-server* \
    && mv code-server-3.1.1-linux-x86_64 /opt/continuum/code-server \
    && ln -s "/opt/continuum/code-server/code-server" \
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
    && cp post-commit pre-push pre-push.py retag.py /opt/continuum/scripts \
    && chmod +x /opt/continuum/scripts/*.sh \
    && chown anaconda:anaconda /opt/continuum/scripts/*.sh \
    && chown anaconda:anaconda /opt/continuum/scripts/merge_vscode_settings.py \
    && rm -f /aesrc/vscode/{*.tar.bz2,*.visx}
