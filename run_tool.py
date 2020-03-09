# -*- coding: utf-8 -*-
# -----------------------------------------------------------------------------
# Copyright 2017 Continuum Analytics, Inc.
#
# All Rights Reserved.
# -----------------------------------------------------------------------------

# Things that are done in this file (not an exhaustive list)
# 1. Runs jupyter or jupyterlab
# 2. Cleans up the execution environment to get rid of a lot of environmental variables.
#    It's not clear why exactly these variables are being cleaned up. Need to dig into that
#    to get a better understanding.

# (low priority) Things to consider doing:
# 1. Turn this into a proper CLI with argparse or, at least, guard the side-effecting code with
#    the standard if __name__ == "__main__":

import json
import os
import sys
from subprocess import PIPE, Popen

import six

TOOL_HOST = os.environ.get("TOOL_HOST", None)
TOOL_PREFIX = os.environ.get("TOOL_PREFIX", None)
TOOL_IFRAME_HOSTS = os.environ.get("TOOL_IFRAME_HOSTS", None)
TOOL_ADDRESS = os.environ.get("TOOL_ADDRESS", None)
TOOL_PORT = os.environ.get("TOOL_PORT", None)

def _is_conda_bindir(path):
    """Check and see if "path" is a /bin directory or if "path" is exactly one subfolder of a conda
    directory

    Parameters
    ----------
    path : str
    An element in the PATH env var

    Returns
    -------
    bool
    False: `path` does not end with "/bin" or "path" is not a sibling directory of "conda-meta".
    The presence of "conda-meta" would indicate that this `path` var is inside of a conda environment directory.
    True: `path` is not a /bin directory or `path` is not a top level directory inside of a
    conda environment
    """
    # consider just replacing this if block with `path = path.rstrip('/')`
    if path.endswith("/"):
        path = path[:-1]
    if not path.endswith("/bin"):
        return False
    possible_prefix = os.path.dirname(path)
    conda_meta_prefix = os.path.join(path, "conda-meta")
    return os.path.isdir(conda_meta_prefix)


def get_activated_env_vars(conda_prefix):
    # The next three functions were essentially pieced together from
    # https://github.com/conda/conda/blob/4.6.0/conda/cli/main_run.py and from
    # https://github.com/conda/conda/blob/4.6.0/conda/cli/conda_argparse.py#L166-L181
    # (with some modifications due to the fact that the version of conda used in the session
    # container is very old...)
    #
    # This function essentially uses the root conda env to activate the lab launch env.
    # To reproduce this behavior locally in the session container, you can run
    # "source /opt/continuum/anaconda/bin/activate /opt/continuum/anaconda/envs/lab_launch"
    inner_builder = (
        "source /opt/continuum/anaconda/bin/activate \"{0}\"".format(conda_prefix),
        "&&",
        "/opt/continuum/anaconda/bin/python -c \"import os, json; print(json.dumps(dict(os.environ)))\"",
    )
    cmd = ("sh", "-c", " ".join(inner_builder))
    env_var_map = json.loads(_check_output(cmd))
    activated_env_vars = {str(k): str(v) for k, v in six.iteritems(env_var_map)}
    return activated_env_vars


def _check_output(cmd):
    # This snippet was taken from https://github.com/conda/conda/blob/4.6.0/conda/cli/main_run.py
    p = Popen(cmd, stdout=PIPE, stderr=PIPE)
    stdout, stderr = p.communicate()
    rc = p.returncode
    assert rc == 0 and not stderr, (rc, stderr)
    return stdout


def activate_env_vars(args, conda_prefix):
    env_vars = get_activated_env_vars(conda_prefix)
    return os.execvpe(args[0], args, env_vars)


def run_tool(working_directory, conda_prefix, package_spec):
    # Based on the start_jupyter function in `startup.sh`, these parameters look like this:
    # working_directory = '/opt/continuum/project'
    # conda_prefix = '/opt/continuum/anaconda/envs/lab_launch' '$TOOL_PACKAGE'"
    # package_spec = 'jupyterlab' or 'notebook'
    #
    # Note that there are only two things that `package_spec` could be at this point: "notebook" or "jupyterlab".
    # This is based on the execution line in `startup.sh`:
    # "elif [ $TOOL_PACKAGE == 'jupyterlab' ] || [ $TOOL_PACKAGE == 'notebook' ]; then"
    if package_spec == 'notebook':
        args = ['jupyter-notebook']
    elif package_spec == 'jupyterlab':
        args = ['jupyter-lab']
    else:
        raise RuntimeError("Not a valid package spec name: %s" % package_spec)

    args.extend((
        '--NotebookApp.trust_xheaders=True',
        '--no-browser',
        # '--debug',
    ))

    assert TOOL_PORT is not None
    args.extend(["--port", TOOL_PORT])

    if TOOL_ADDRESS is not None:
        args.extend(['--ip', TOOL_ADDRESS])

    if TOOL_HOST is not None:
        # our hardcoded jupyter example doesn't need this...
        # args.extend(["--host", TOOL_HOST])
        # but anaconda-project-lab's proxy needs this...
        args.extend(['--PrototypeManager.extra_hosts=["{}"]'.format(TOOL_HOST)])

    if TOOL_PREFIX is not None:
        args.extend(["--NotebookApp.base_url=" + TOOL_PREFIX])

    if TOOL_IFRAME_HOSTS is not None:
        value = "'self' %s" % TOOL_IFRAME_HOSTS
        python_dict_literal = """{ 'headers': { 'Content-Security-Policy': "frame-ancestors """ + \
                              value + '" } }'
        args.extend(['--NotebookApp.tornado_settings=' + python_dict_literal])

    os.chdir(working_directory)
    print("  Editor working directory %s" % working_directory)
    print("Editor command line: %r" % args)

    activate_env_vars(args, conda_prefix)

if len(sys.argv) != 4:
    print("Pass in the cwd, conda prefix, and the package to run", file=sys.stderr)
    sys.exit(1)

run_tool(working_directory=sys.argv[1], conda_prefix=sys.argv[2], package_spec=sys.argv[3])
