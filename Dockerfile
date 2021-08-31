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
    && chown -fR anaconda:0 code-server-* \
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
    ## copy new script files
    && SCRIPTS=(start_vscode.sh activate-env-spec.sh apply_python_path.py default_env_spec.py default_env_spec_prefix.py) \
    && for scpt in ${SCRIPTS[@]}; do \
         cp $scpt /opt/continuum/scripts/$scpt; \
         chown anaconda:0 /opt/continuum/scripts/$scpt;  \
         chmod +x /opt/continuum/scripts/$scpt; \
       done \
    ##
    ## Cleanup
    && rm -rf /aesrc/vscode/downloads \
    && rm -f /aesrc/vscode/{"*.tar.bz2", "*.tar.gz", "*.visx", "examples"} \
    && rm -rf /opt/continuum/.local
