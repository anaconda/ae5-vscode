#!/bin/bash

echo "+-- START: AE5 VSCode Launcher ---"

OC=/opt/continuum
OCV=$OC/.vscode
OCA=$OC/anaconda
OCP=$OC/project
OCAB=$OCA/bin
OCLL=$OCA/envs/lab_launch
OCLB=$OCLL/bin

SETTINGS="/var/run/secrets/user_credentials/vscode_settings"

export CONDA_EXE=$OCA/bin/conda
export CONDA_DESIRED_ENV=$(cd $OCP && $OCLB/anaconda-project list-env-specs </dev/null | grep -A1 ^= | tail -1)
ENV_PREFIX="$ANACONDA_PROJECT_ENVS_PATH/$CONDA_DESIRED_ENV"
echo "| Prefix: $ENV_PREFIX"

sed -E -i 's@("python.pythonPath":\s*")[^"]*(")@\1'"$ENV_PREFIX/bin/python"'\2@' $OCV/project.code-workspace
echo "| Workspace Settings file $OCV/project.code-workspace:"
echo "|---"
sed 's@^@|  @' $OCV/project.code-workspace
echo "|---"

pip install jsonmerge
python /opt/continuum/scripts/merge_vscode_settings.py $SETTINGS

export NODE_EXTRA_CA_CERTS=$OCLL/ssl/cacert.pem

args=($OCLB/code-server --auth none --user-data-dir $OCV)
[[ $TOOL_PORT ]] && args+=(--port $TOOL_PORT)
[[ $TOOL_ADDRESS ]] && args+=(--host $TOOL_ADDRESS)
args+=($OCV/project.code-workspace)

echo "| Command line: ${args[@]}"
echo "+-- END: AE5 VSCode Launcher ---"

cd $OCP
exec "${args[@]}"
