#!/bin/bash

echo "+-- START: AE5 VSCode Launcher ---"

OC=/opt/continuum
OCV=$OC/.vscode
OCA=$OC/anaconda
OCP=$OC/project
OCAB=$OCA/bin
OCLL=$OCA/envs/lab_launch
OCLB=$OCLL/bin

#SETTINGS=$OCV/User/settings.json
###
# If not using persistent storage replace the above
# with this path for users to keep their settings in
# a secret
#SETTINGS="/var/run/secrets/user_credentials/vscode_settings"

export CONDA_EXE=$OCA/bin/conda
export CONDA_DESIRED_ENV=$(cd $OCP && python $OC/scripts/default_env_spec.py)
ENV_PREFIX=$(cd $OCP && python $OC/scripts/default_env_spec_prefix.py)
echo "| Prefix: $ENV_PREFIX"
python $OC/scripts/apply_python_path.py $ENV_PREFIX/bin/python

#if [ ! -f $OCP/.vscode/project.code-workspace ]; then
#	mkdir -p $OCP/.vscode
#	cp /aesrc/vscode/project.code-workspace $OCP/.vscode/project.code-workspace
#	sed -E -i 's@("python.pythonPath":\s*")[^"]*(")@\1'"$ENV_PREFIX/bin/python"'\2@' $OCP/.vscode/project.code-workspace
#	echo "| Workspace Settings file $OCP/project.code-workspace:"
#	echo "|---"
#	sed 's@^@|  @' $OCP/.vscode/project.code-workspace
#	echo "|---"
#fi

#sed -E -i 's@lab_launch@'"$CONDA_DESIRED_ENV"'@' $OCV/activate-env-spec.sh

# Only merge admin settings if the settings file is empty
# This effectively means "on-first-run" of any project with
# VSCode
#if [ ! -s "$SETTINGS" ]; then
#	cp $OCV/admin_settings.json $SETTINGS
	#python /opt/continuum/scripts/merge_vscode_settings.py $SETTINGS
#fi

export NODE_EXTRA_CA_CERTS=$OCLL/ssl/cacert.pem
export BOKEH_ALLOW_WS_ORIGIN=$TOOL_HOST          ## allows bokeh apps to work with proxy
export XDG_DATA_HOME=$OCV                        ## implement last-visited in coder.json
export XDG_CONFIG_HOME=$OCV                      ## everything goes in ~/.vscode

## Git configs to allow push without arguments
# git config push.default upstream 
# git branch -u origin/master

## configure pre-push hook to POST revision metadata
# cp $OC/scripts/pre-push $OCP/.git/hooks
# chmod 755 $OCP/.git/hooks/pre-push

## post-commit message to reminder user to tag and push
# cp $OC/scripts/post-commit $OCP/.git/hooks
# chmod 755 $OCP/.git/hooks/post-commit

args=($OCLB/code-server --auth none --user-data-dir $OCV --bind-addr 0.0.0.0:7050) 
args+=(--disable-telemetry)
args+=(--log debug)
[[ $TOOL_PORT ]] && args+=(--port $TOOL_PORT)
[[ $TOOL_ADDRESS ]] && args+=(--host $TOOL_ADDRESS)

echo "| Command line: ${args[@]}"
echo "+-- END: AE5 VSCode Launcher ---"

cd $OCP
exec "${args[@]}"
