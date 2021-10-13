#!/bin/bash

echo "+-- START: AE5 VSCode Launcher ---"

TOOL_HOME=$(dirname "${BASH_SOURCE[0]}")
OC=$HOME

echo "| Tool home: $TOOL_HOME"
echo "| User home: $OC"

OCV=$OC/.vscode
OCC=$OC/.config
OCA=$OC/anaconda
OCP=$OC/project
OCCC=$OCC/code-server
OCLB=$OCLL/bin

SETTINGS="/var/run/secrets/user_credentials/vscode_settings"

# Determine the conda environment specified by the project

export CONDA_EXE=$OCA/bin/conda
export CONDA_DESIRED_ENV=$($OCA/bin/python $TOOL_HOME/default_env.py $OCP)
ENV_PREFIX=$(source $OCA/bin/activate $CONDA_DESIRED_ENV && echo $CONDA_PREFIX)
[ -d "$ENV_PREFIX" ] || ENV_PREFIX=$OCA
echo "| Prefix: $ENV_PREFIX"

#
# Build the configuration files in ~/.config/code-server
# These must not live in persistent storage so that users
# can have multiple running sessions.
#

mkdir -p $OCCC
if [ "$(readlink $OCV/code-server 2>&1)" != "$OCCC" ]; then
    echo "| Fixing code-server configuration directory link"
    rm -rf $OCV/code-server 2>&1 || :
    ln -s $OCCC $OCV/
    ls -l $OCV/code-server | sed 's@^@| @'
fi
echo "| Creating configuration files"
write_file() {
    echo "| $1:"
    echo "|----"
    tee $OCCC/$1 | sed 's@^@| @'
    echo "|----"
}
write_file project.code-workspace <<EOD
{"folders": [{"path": "$OCP"}],
 "settings": {"python.pythonPath": "$ENV_PREFIX"}}
EOD
write_file coder.json <<EOD
{"lastVisited": {
 "path": "$OCCC/project.code-workspace",
 "workspace": true,
 "url": "$OCCC/project.code-workspace"
}}
EOD

#
# Build the user settings file in ~/.vscode/User/settings.json.
# Because some of those settings should not be changed by users,
# we put them in $TOOL_HOME/admin_settings.json and merge them
# into the settings JSON on session startup.
#

mkdir -p $OCV/User
python $TOOL_HOME/merge_settings.py $SETTINGS | sed 's@^@| @'

# Final environment tweaks

export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-chain.pem
export BOKEH_ALLOW_WS_ORIGIN=$TOOL_HOST          ## allows bokeh apps to work with proxy
export XDG_DATA_HOME=$OCV                        ## implement last-visited in coder.json

# Build the command line

args=($TOOL_HOME/bin/code-server --auth none --user-data-dir $OCV)
args+=(--extensions-dir $TOOL_HOME/extensions --disable-telemetry)
[[ $TOOL_PORT ]] && args+=(--port $TOOL_PORT)
[[ $TOOL_ADDRESS ]] && args+=(--host $TOOL_ADDRESS)

echo "| Command line: ${args[@]}"
echo "+-- END: AE5 VSCode Launcher ---"

cd $OCP
exec "${args[@]}"
