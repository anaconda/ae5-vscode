#!/bin/bash

echo "+-- START: AE5 VSCode Launcher ---"

TOOL_HOME=$(dirname "${BASH_SOURCE[0]}")
OC=$HOME

echo "| Tool home: $TOOL_HOME"
echo "| User home: $OC"

OCV=$OC/.vscode
OCA=$OC/anaconda
OCP=$OC/project
OCD=$OC/data
OCUH=$OC/user/home
OCUHV=$OC/user/home/vscode

SETTINGS="/var/run/secrets/user_credentials/vscode_settings"
PYTHON=$OCA/bin/python
CONFIG=$OC/.config/code-server
CONFIG_U=$CONFIG/User

# Determine the conda environment specified by the project

export CONDA_EXE=$OCA/bin/conda
export CONDA_DESIRED_ENV=$($PYTHON $TOOL_HOME/default_env.py $OCP)
ENV_PREFIX=$(source $OCA/bin/activate $CONDA_DESIRED_ENV && echo $CONDA_PREFIX)
[ -d "$ENV_PREFIX" ] || ENV_PREFIX=$OCA
echo "| Prefix: $ENV_PREFIX"

#
# Build the configuration files in ~/.config/code-server
# These must not live in persistent storage so that users
# can have multiple running sessions.
#

if [[ ! -d $OCV && -d $OCUH ]]; then
    # Persist ~/.vscode if possible
    mkdir -p $OCUHV
    ln -s $OCUHV $OCV
fi
mkdir -p $CONFIG_U $OCV/globalStorage $OCP/.vscode
ln -s $OCV/settings.json $CONFIG_U
ln -s $OCV/globalStorage $CONFIG_U
if [ -d $OCD ]; then
    mkdir -p $OCD/.vscode/workspaceStorage
    ln -s $OCD/.vscode/workspaceStorage $CONFIG_U
fi
echo "|---- $CONFIG/coder.json ----"
tee $CONFIG/coder.json <<EOD | sed 's@^@| @'
{"query": {"folder": "$OCP"},
 "lastVisited": {"url": "$OCP", "workspace": false}}
EOD
echo "|----"

#
# Build the user settings file in ~/.vscode/User/settings.json.
# Because some of those settings should not be changed by users,
# we put them in $TOOL_HOME/admin_settings.json and merge them
# into the settings JSON on session startup.
#

$PYTHON $TOOL_HOME/merge_settings.py user "$SETTINGS" | sed 's@^@| @'
$PYTHON $TOOL_HOME/merge_settings.py project "$ENV_PREFIX" | sed 's@^@| @'

# Final environment tweaks

export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-chain.pem
export BOKEH_ALLOW_WS_ORIGIN=$TOOL_HOST          ## allows bokeh apps to work with proxy
export XDG_DATA_HOME=$(dirname $CONFIG)          ## implement last-visited in coder.json
export XDG_CONFIG_HOME=$XDG_DATA_HOME

# Build the command line

args=($TOOL_HOME/bin/code-server --auth none --disable-update-check --user-data-dir $CONFIG)
args+=(--extensions-dir $TOOL_HOME/extensions --disable-telemetry)
[[ $TOOL_PORT ]] && args+=(--port $TOOL_PORT)
[[ $TOOL_ADDRESS ]] && args+=(--host $TOOL_ADDRESS)
args+=($OCP)

echo "| Command line: ${args[@]}"
echo "+-- END: AE5 VSCode Launcher ---"

cd $OC
exec "${args[@]}"
