#!/bin/bash

echo "- AE5 VSCode Installer"

if ! grep -q /tools/ /opt/continuum/scripts/start_user.sh; then
    echo "ERROR: This version of the VSCode installer requires AE5.5.1 or later."
    exit -1
fi
    
CURRENT_DIR=$PWD
SOURCE_DIR=$(dirname "${BASH_SOURCE[0]}")
missing=
for sfile in activate.sh admin_settings.json merge_settings.py start_vscode.sh; do
    spath=$CURRENT_DIR/$sfile
    [ -f $spath ] || spath=$SOURCE_DIR/$sfile
    [ -f $spath ] || missing="$missing $sfile"
done
if [ ! -z "$missing" ]; then
    echo "ERROR: missing support files:$missing"
    exit -1
fi

# PREFIX: where the *final* install will live
# STAGING_PREFIX: where we are building it for now
# Allowing these to be different simplifies our ability
# to create VSCode tarballs in one location and install
# them in another.
[ $PREFIX ] || PREFIX=/tools/vscode
[ $STAGING_PREFIX ] || STAGING_PREFIX=$PREFIX
echo "- Install prefix: ${PREFIX}"
echo "- Staging prefix: ${STAGING_PREFIX}"
if [ ! -d $STAGING_PREFIX ]; then
    parent=$(dirname $STAGING_PREFIX)
    if [[ $PREFIX == $STAGING_PREFIX && ! -d $parent ]]; then
        echo "ERROR: install parent $parent does not exist"
        exit -1
    elif ! mkdir -p $STAGING_PREFIX; then
        echo "ERROR: could not create install directory"
        exit -1
    fi
elif [ ! -w $STAGING_PREFIX ]; then
    echo "ERROR: install location is not writable"
    ls -ald $STAGING_PREFIX
    id
    exit -1
elif [ ! -z "$(ls -A $STAGING_PREFIX)" ]; then
    echo "ERROR: install location is not empty"
    ls -al $STAGING_PREFIX
    exit -1
fi

PYTHON_EXE=/opt/continuum/anaconda/bin/python
if [ -f downloads/code-server-* ]; then
    echo "- Using existing downloads directory"
elif [ -f downloads.tar.bz2 ]; then
    echo "- Unpacking downloads tarball"
    tar xfj downloads.tar.bz2
elif [ -f downloads.tar.gz ]; then
    echo "- Unpacking downloads tarball"
    tar xfz downloads.tar.gz
else
    echo "- Retrieving packages from manifest"
    $PYTHON_EXE download.py
fi

echo "- Installing code-server"
tar xfz downloads/code-server.tar.gz
mv code-server-*/* $STAGING_PREFIX
rmdir code-server-*

echo "- Installing extensions"
mkdir -p $STAGING_PREFIX/extensions
for ext in downloads/extensions/*.vsix; do \
    echo "- $ext"
    $STAGING_PREFIX/bin/code-server --extensions-dir=$STAGING_PREFIX/extensions --install-extension $ext
done

echo "- Run the post-install scripts"
$PYTHON_EXE download.py --post-install

echo "- Run the Python extension patcher"
$PYTHON_EXE patch_python_extension.py $STAGING_PREFIX

echo "- Installing support scripts"
cp admin_settings.json activate.sh start_vscode.sh merge_settings.py \
    patch_python_extension.py default_env.py $STAGING_PREFIX
if [ "$PREFIX" != "/tools/vscode" ]; then
    sed -i.bak "s@/tools/vscode/@$PREFIX/@" $STAGING_PREFIX/{admin_settings.json,activate.sh}
fi
chmod +x $STAGING_PREFIX/{activate.sh,start_vscode.sh}

echo "- Installed. You can shut down this session, and/or remove downloaded files."

if [ "$PREFIX" != "$STAGING_PREFIX" ]; then
    echo "- To build the tarball for delivery; run this command:"
    echo "-    tar cfz ae5-vscode.tar.gz -C $STAGING_PREFIX ."
    echo "- To install the tarball at the destination; upload and run:"
    echo "-    tar xfz ae5-vscode.tar.gz -C $PREFIX"
fi


