#!/bin/bash

echo "+-- START: AE5 VSCode Launcher ---"

OC=/opt/continuum
OCV=$OC/.vscode
OCVU=$OCV/User
OCA=$OC/anaconda
OCP=$OC/project
OCAB=$OCA/bin
OCLL=$OCA/envs/lab_launch
OCLB=$OCLL/bin

export CONDA_EXE=$OCA/bin/conda
export CONDA_DESIRED_ENV=$(cd $OCP && $OCLB/anaconda-project list-env-specs </dev/null | grep -A1 ^= | tail -1)
if [ "$CONDA_DESIRED_ENV" ]; then
    echo "| Target environment: $CONDA_DESIRED_ENV"
    source $OCA/bin/activate $CONDA_DESIRED_ENV || \
        echo "| ERROR: Environment activation failed"
else
    echo "| Missing or corrupt anaconda-project.yml file"
fi
echo "| Prefix: $CONDA_PREFIX"

sed -E -i 's@("python.pythonPath":\s*")[^"]*(")@\1'"$CONDA_PREFIX/bin/python"'\2@' $OCVU/settings.json
echo "| Settings file $OCVU/settings.json:"
echo "|---"
sed 's@^@|  @' $OCVU/settings.json
echo "|---"
export NODE_EXTRA_CA_CERTS=$OCLL/ssl/cacert.pem

args=($OCLB/code-server --auth none --user-data-dir $OCV)
[[ $TOOL_PORT ]] && args+=(--port $TOOL_PORT)
[[ $TOOL_ADDRESS ]] && args+=(--host $TOOL_ADDRESS)
args+=($OCP)

echo "| Command line: ${args[@]}"
echo "+-- END: AE5 VSCode Launcher ---"

cd $OCP
exec "${args[@]}"
