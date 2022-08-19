#!/bin/bash

echo "+----------------------+"
echo "| AE5 VSCode Installer |"
echo "+----------------------+"

TOOL_HOME=$(dirname "${BASH_SOURCE[0]}")

if ! grep -q /tools/ /opt/continuum/scripts/start_user.sh; then
    echo "ERROR: This version of the VSCode installer requires AE5.5.1 or later."
    exit -1
fi

echorun() {
  echo "> $@"
  "$@" | sed 's@^@| @'
}

CURRENT_DIR=$PWD
SOURCE_DIR=$(dirname "${BASH_SOURCE[0]}")
missing=
for sfile in MANIFEST activate.sh admin_settings.json merge_settings.py patch_python_extension.py start_vscode.sh; do
    spath=$CURRENT_DIR/$sfile
    [ -f $spath ] || spath=$SOURCE_DIR/$sfile
    [ -f $spath ] || missing="$missing $sfile"
done
if [ ! -z "$missing" ]; then
    echo "ERROR: missing support files:$missing"
    exit -1
fi

missing=
vscode_fname=$(sed -nE 's@(.*/)?(code-server-.*)@\2@p' MANIFEST)
if [ -z "$vscode_fname" ]; then
    echo "ERROR: could not find the code-server binary in the MANIFEST"
    exit -1
fi
[ -f "downloads/$vscode_fname" ] || missing="$missing $vscode_fname"
for fname in $(sed -nE 's@(.*/)?([^/]*.vsix)@\2@p' MANIFEST); do
    [ -f "downloads/$fname" ] || missing="$missing $fname"
done
if [ ! -z "$missing" ]; then
    echo "ERROR: missing files:$missing"
    echo "(Have you run download_vscode.sh?)"
    exit -1
fi

# PREFIX: where the *final* install will live
# STAGING_PREFIX: where we are building it for now
# Allowing these to be different simplifies our ability
# to create VSCode tarballs in one location and install
# them in another.
[ $PREFIX ] || PREFIX=/tools/vscode
[ $STAGING_PREFIX ] || STAGING_PREFIX=$PREFIX
if [ $(basename "$PREFIX") != $(basename "$STAGING_PREFIX") ]; then
    echo "ERROR: in order to facilitate proper distribution, the"
    echo "basename of PREFIX and STAGING_PREFIX must be identical."
    echo "- PREFIX: $PREFIX"
    echo "- STAGING_PREFIX: $STAGING_PREFIX"
    echo "Please choose a different STAGING_PREFIX value and retry."
    exit -1
fi

echo "| Install prefix: ${PREFIX}"
echo "| Staging prefix: ${STAGING_PREFIX}"
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

echo "- Installing code-server"

echorun tar xfz downloads/$vscode_fname --strip-components 1 -C $STAGING_PREFIX

echo "- Installing extensions"
mkdir -p $STAGING_PREFIX/extensions
for ext in $(sed -nE 's@(.*/)?([^/]*.vsix)@\2@p' MANIFEST); do
    echorun $STAGING_PREFIX/bin/code-server \
        --extensions-dir=$STAGING_PREFIX/extensions --install-extension=downloads/$ext
done

echo "- Run the Python extension patcher"
echorun $PYTHON_EXE patch_python_extension.py $STAGING_PREFIX

echo "- Installing support scripts"
cp admin_settings.json activate.sh start_vscode.sh merge_settings.py \
    patch_python_extension.py default_env.py $STAGING_PREFIX
if [ "$PREFIX" != "/tools/vscode" ]; then
    sed -i.bak "s@/tools/vscode/@$PREFIX/@" $STAGING_PREFIX/{admin_settings.json,activate.sh}
fi
chmod +x $STAGING_PREFIX/{activate.sh,start_vscode.sh}

echo "Installed. You can shut down this session, and/or remove downloaded files."

if [ "$PREFIX" != "$STAGING_PREFIX" ]; then
    echo "To build as tarball for delivery; run this command:"
    echo "   tar cfz ae5-vscode.tar.gz -C $(dirname $STAGING_PREFIX) $(basename $STAGING_PREFIX)"
    echo "To install the tarball at the destination, run:"
    echo "   mkdir -p $(dirname $PREFIX)"
    echo "   tar xfz ae5-vscode.tar.gz -C $(dirname $PREFIX)"
fi
