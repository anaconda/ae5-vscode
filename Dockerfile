ARG WORKSPACE
FROM $WORKSPACE
COPY . /aesrc/vscode/
ARG AIRGAPPED=FALSE
USER root
RUN set -ex \
    && cd /aesrc/vscode \
    ## jq is very helpful
    && /opt/continuum/anaconda/bin/conda install -n lab_launch jq -y \
    ##
    ## Download code-server and extensions
    && if [[ "$AIRGAPPED" == "TRUE" ]]; then \
         curl -O http://localhost:8000/downloads.tar.bz2; \
         bunzip2 downloads.tar.bz2; \
         tar xf downloads.tar; \
         rm downloads.tar; \
       else \
         /opt/continuum/anaconda/envs/lab_launch/bin/python download.py; \
       fi \
    ##
    ## install code-server
    && tar xfz downloads/code-server.tar.gz \
    && chown -fR anaconda code-server-* \
    && mv code-server-* /opt/continuum/anaconda/envs/lab_launch/lib/code-server \
    && ln -s "/opt/continuum/anaconda/envs/lab_launch/lib/code-server/bin/code-server" \
          /opt/continuum/anaconda/envs/lab_launch/bin \
    ##
    ## Move in the user-data-dir
    && rm -rf /opt/continuum/scripts/skeletons/user/home/.vscode \
    && mv vscode /opt/continuum/scripts/skeletons/user/home/.vscode \
    && chown -fR anaconda:0 /opt/continuum/scripts/skeletons/user/home/.vscode \
    ##
    ## install extensions
    && for ext in downloads/extensions/*.vsix; do \
        su anaconda -c \
          "/opt/continuum/anaconda/envs/lab_launch/bin/code-server \
          --user-data-dir /opt/continuum/scripts/skeletons/user/home/.vscode \
          --install-extension $ext"; \
       done \
    ##
    ## extension post-install
    && /opt/continuum/anaconda/envs/lab_launch/bin/python download.py --post-install \
    ##
    ## Choose the right startup script
    && if [ ! -f /opt/continuum/scripts/start_user.sh ]; then \
           cp start_*.sh startup.sh build_condarc.py run_tool.py /opt/continuum/scripts; \
       else \
           cp start_vscode.sh /opt/continuum/scripts; \
       fi \
    ##
    #&& cp merge_vscode_settings.py /opt/continuum/scripts \
    && cp activate-env-spec.sh /opt/continuum/scripts \
    && cp apply_python_path.py /opt/continuum/scripts \
    && cp default_env_spec.py /opt/continuum/scripts \
    && cp default_env_spec_prefix.py /opt/continuum/scripts \
    ##
    && chmod +x /opt/continuum/scripts/*.sh \
    && chown -R anaconda /opt/continuum/scripts/* \
    ##
    ## Cleanup
    && rm -rf /aesrc/vscode/downloads \
    && rm -f /aesrc/vscode/{"*.tar.bz2", "*.tar.gz", "*.visx", "examples"}
