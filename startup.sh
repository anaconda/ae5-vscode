#!/bin/bash

# ************ THIS SCRIPT RUNS AS ROOT

# print background job status immediately not on next command
set -b

# bail out on unhandled errors
set -e

set -x

# without this, when not isatty(stdin) python does not flush
# print() on newlines, which is confusing.
export PYTHONUNBUFFERED=1

# Tell anaconda-project that the envs don't live in the project directory.
# We put them outside the project dir, because we mount a kubernetes volume
# on /opt/continuum/project, which would hide the pre-built envs that are
# in the editor docker image.
export ANACONDA_PROJECT_ENVS_PATH=/opt/continuum/anaconda/envs


function echo_off {
    # run a command without echoing all the stuff it does internally
    set +x
    echo "$@"
    eval "$@"
    set -x
}


# TODO: Document what this is doing...
function start_sync() {
    echo_off source activate sync_launch
    cd /opt/continuum/project

    exec su anaconda -c "anaconda-platform-sync \
        --anaconda-project-host=$TOOL_HOST \
        --anaconda-project-host=$TOOL_SERVICE_ADDRESS:$TOOL_PORT \
        --anaconda-project-port=$TOOL_PORT \
        --anaconda-project-address=$TOOL_ADDRESS \
        --anaconda-project-url-prefix=$TOOL_PREFIX \
        --anaconda-project-iframe-hosts=$TOOL_IFRAME_HOSTS \
        -Dsync.owner=\"$TOOL_OWNER\" \
        -Dsync.email=\"$TOOL_OWNER_EMAIL\" \
        -Dsync.project-url=$TOOL_PROJECT_URL \
        -Dsync.local-branch=$TOOL_PROJECT_BRANCH \
        -Dsync.https.certificate-authority=/var/run/secrets/anaconda/ca-chain.pem \
        -Dstorage.url=$TOOL_STORAGE_URL \
        -Dauth-server.realm=\"$TOOL_AUTH_REALM\" \
        -Dauth-server.url=\"$TOOL_AUTH_URL\" "
}


function wait_for_project_file {
    set +x
    cd /opt/continuum/project
    while [ ! -f anaconda-project.yml -o -f anaconda-project.yaml ]; do   #  > /dev/null 2>&1
        echo "waiting for anaconda-project file"
        ls -lA /opt/continuum/project
        # TODO: Reconsider this 2 second sleep -- is it arbitrary?
        sleep 2
    done
    set -x
}

function prepare_default_env {
    # hopefully we found default in the env cache, but if not,
    # we'll create it from scratch here
    if [ -f anaconda-project.yml ] || [ -f anaconda-project.yaml ]; then
        echo_off source activate lab_launch
        echo 'copying config files'
        # runs as root, to be able to write anywhere
        python /opt/continuum/scripts/config_copy.py
        echo 'running anaconda-project prepare'
        # TODO: Figure out why we are adding this --mode flag here. Document why this flag matters
        su anaconda -c "anaconda-project prepare --mode development_defaults" &> /opt/continuum/preparing
        mv -f /opt/continuum/preparing /opt/continuum/prepare.log
    else
        echo 'no anaconda-project.yml file found; not running prepare'
    fi
}


function run_dummy_server {
    echo '*** TEST MODE ***'
    echo 'Running dummy server'

    echo 'copying config files'
    # runs as root, to be able to write anywhere
    python /opt/continuum/scripts/config_copy.py
    # give it something to serve on /$TOOL_ID
    mkdir $TOOL_ID
    exec su anaconda -c "python -m http.server ${TOOL_PORT}"
}


function die() {
    echo $* 1>&2
    exit 1
}

TOOL_SUDO_YUM=$(echo "$TOOL_SUDO_YUM" | tr -d '"')
echo "Sudo yum: $TOOL_SUDO_YUM"
if [ "$TOOL_SUDO_YUM" == "disable" ]; then
    grep -v "anaconda ALL=(ALL) NOPASSWD: /usr/bin/yum" /etc/sudoers > sudoers2; mv sudoers2 /etc/sudoers
    echo "Sudo yum has been disabled."
elif [ "$TOOL_SUDO_YUM" == "enable" ]; then
    echo "anaconda ALL=(ALL) NOPASSWD: /usr/bin/yum" >> /etc/sudoers
    echo "Sudo yum has been enabled."
fi

test -d /opt/continuum/project || die "Expecting /opt/continuum/project to exist"

eval `ssh-agent -s`  # useful for any SSH keys used in the Session

echo "PS1='(\$(basename \${CONDA_PREFIX})) '" >> /opt/continuum/.bashrc

if test x"$TOOL_PACKAGE" = x""; then
    die "Must set TOOL_PACKAGE"
fi

if [ -s "/var/run/secrets/anaconda/platform-token" ]; then
    TOKEN=`cat /var/run/secrets/anaconda/platform-token`
    echo 'using auth token'
    su anaconda -c "/opt/continuum/scripts/save-conda-token '${TOOL_CONDA_URL}' '${TOKEN}'"
fi

if [ $TOOL_PACKAGE == 'anaconda-platform-sync' ]; then
    start_sync
elif [[ $TOOL_PACKAGE =~ dummy. ]]; then
    run_dummy_server
fi

time wait_for_project_file
su anaconda -c "python /opt/continuum/scripts/build_condarc.py"
touch /opt/continuum/preparing
time prepare_default_env &

start_script=/opt/continuum/scripts/start_${TOOL_PACKAGE}.sh
[ -f "$start_script" ] || die "Invalid TOOL_PACKAGE: ${TOOL_PACKAGE}"
echo "Executing $start_script"
echo "-----------"

exec su anaconda -c "$start_script"

