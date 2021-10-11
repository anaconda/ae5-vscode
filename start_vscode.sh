#!/bin/bash

echo "+-- START: AE5 VSCode Launcher ---"

OC=/opt/continuum
OCV=$OC/.vscode
OCA=$OC/anaconda
OCP=$OC/project
OCAB=$OCA/bin
OCCC=$OC/.config/code-server
OCLL=$OCA/envs/lab_launch
OCLB=$OCLL/bin
TV=/tools/vscode

SETTINGS="/var/run/secrets/user_credentials/vscode_settings"

export CONDA_EXE=$OCA/bin/conda
export CONDA_DESIRED_ENV=$(cd $OCP && $OCLB/anaconda-project list-env-specs </dev/null | grep -A1 ^= | tail -1)
ENV_PREFIX=$(source activate $CONDA_DESIRED_ENV && echo $CONDA_PREFIX)
echo "| Prefix: $ENV_PREFIX"

echo "| Copying skeleton into $OC/.vscode (w/o clobbering)"
cp -prn $TV/vscode/. $OCV/ || :
(cd $OCV && find .) | sed 's@^@| @'

sed -E -i 's@("python.pythonPath":\s*")[^"]*(")@\1'"$ENV_PREFIX/bin/python"'\2@' $OCV/project.code-workspace
echo "| Workspace Settings file $OCV/project.code-workspace:"
echo "|---"
sed 's@^@|  @' $OCV/project.code-workspace
echo "|---"

mkdir -p $OCCC
sed -E 's@lab_launch@'"$CONDA_DESIRED_ENV"'@' $TV/activate-env-spec.sh > $OCCC/activate-env-spec.sh
chmod +x $OCCC/activate-env-spec.sh

python $TV/merge_vscode_settings.py $SETTINGS

export NODE_EXTRA_CA_CERTS=$OCLL/ssl/cacert.pem
export BOKEH_ALLOW_WS_ORIGIN=$TOOL_HOST          ## allows bokeh apps to work with proxy
export XDG_DATA_HOME=$OCV                        ## implement last-visited in coder.json

args=($TV/bin/code-server --auth none --user-data-dir $OCV --extensions-dir $TV/extensions --disable-telemetry)
[[ $TOOL_PORT ]] && args+=(--port $TOOL_PORT)
[[ $TOOL_ADDRESS ]] && args+=(--host $TOOL_ADDRESS)

echo "| Command line: ${args[@]}"
echo "+-- END: AE5 VSCode Launcher ---"

cd $OCP
exec "${args[@]}"