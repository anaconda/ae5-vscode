#!/bin/bash

OC=/opt/continuum
ZEP=$OC/zeppelin-0.8.0-bin-all
mkdir -p $ZEP/logs $ZEP/run

# Previous versions of this script did only partial activation of the
# project environment. This attempts a full activation, but we can't
# afford to do nothing if that fails--for instance, if the environment
# is fully custom, and therefore has not been instantiated yet. So if
# activation fails, we manaully set CONDA_PREFIX, CONDA_DEFAULT_ENV,
# and PATH, in anticipation of the completed environment build.
VERSION=$(anaconda-project list-env-specs | grep -A1 ^= | tail -1)
echo "- project environment: $VERSION"
if source activate $VERSION; then
    echo "- environment fully activated"
else
    echo "- full activation failed; performing partial activation"
    source deactivate
    export CONDA_PREFIX=$OC/anaconda/envs/$VERSION
    export CONDA_DEFAULT_ENV=$VERSION
    export PATH=$OC/anaconda/envs/$VERSION/bin:$PATH
fi
echo "- CONDA_PREFIX: $CONDA_PREFIX"
echo "- CONDA_DEFAULT_ENV: $CONDA_DEFAULT_ENV"
echo "- PATH: $PATH"

ENV_FILE=$ZEP/conf/zeppelin-env.sh
# This was hardcoded to 7050 before, but it should track TOOL_PORT
if [ $TOOL_PORT ]; then
	echo "- using TOOL_PORT: $TOOL_PORT"
	echo "export ZEPPELIN_PORT=$TOOL_PORT" >>$ENV_FILE
fi
echo "export PYTHONPATH=$CONDA_PREFIX" >>$ENV_FILE
echo "export PYSPARK_PYTHON=$CONDA_PREFIX/bin/python" >>$ENV_FILE
echo "-- $ENV_FILE --"
tail -3 $ENV_FILE
echo "----"

if [ $TOOL_IFRAME_HOSTS ]; then
	echo "- using TOOL_IFRAME_HOSTS: $TOOL_IFRAME_HOSTS"
	SITE_FILE=$ZEP/conf/zeppelin-site.xml
	sed -i -e "s,<value>SAMEORIGIN</value>,<value>$TOOL_IFRAME_HOSTS</value>,g" $SITE_FILE
	echo "-- $SITE_FILE --"
	grep -B 1 -A 3 zeppelin.server.xframe.options $SITE_FILE
	echo "----"
fi

echo "- launching zeppelin"
exec $ZEP/bin/zeppelin.sh
