# 1. This script formats the condarc that is persisted into the session container at runtime.
#   Specifically, it:
#   a. Adds in channels from the CONDA_CHANNELS env var
#   b. Adds in default channels from the CONDA_DEF_CHANNELS env var
#   c. Writes the condarc file to ~/.condarc in the user's home directory

import json
import os

import ruamel_yaml as yaml

CONDA_URL = os.environ.get('TOOL_CONDA_URL', '')

CONDA_CHANNELS = os.environ.get('TOOL_CONDA_CHANNELS', '')
CONDA_DEF_CHANNELS = os.environ.get('TOOL_CONDA_DEF_CHANNELS', '')
CONDA_SSL_VERIFY = os.environ.get('TOOL_CONDA_SSL_VERIFY', '')
CONDA_OTHER_VARIABLES = os.environ.get('TOOL_CONDA_OTHER_VARIABLES', '')

# make .condarc
template = """auto_update_conda: False
show_channel_urls: True
ssl_verify: {ssl_verify}
channel_alias: {alias}
"""

conda_config = template.format(alias=CONDA_URL, ssl_verify=CONDA_SSL_VERIFY)

if CONDA_CHANNELS:
    channels = json.loads(CONDA_CHANNELS)
    if channels:
        conda_config += "\nchannels: " + ''.join(['\n- ' + ch for ch in channels])

# Add the default channels
if CONDA_DEF_CHANNELS:
    channels = json.loads(CONDA_DEF_CHANNELS)
    if channels:
        conda_config += "\ndefault_channels: " + ''.join(['\n- ' + ch for ch in channels])
    elif channels == []:
        conda_config += "\ndefault_channels: []"

# Add any miscellaneous conda configuration vars (e.g. proxy_servers) here
if CONDA_OTHER_VARIABLES:
    try:
        vars = json.loads(CONDA_OTHER_VARIABLES)
        if vars:
            # Round trip dumper is used to preserve format
            conda_config += "\n" + yaml.dump(vars, Dumper=yaml.RoundTripDumper, allow_unicode=True,
                                      block_seq_indent=2, default_flow_style=False, indent=2)
    except:
        print('Created default condarc without additional variables')

if __name__ == '__main__':
    # More info about conda paths
    # https://www.anaconda.com/blog/developer-blog/conda-configuration-engine-power-users/
    with open(os.path.join(os.path.expanduser('~'), '.condarc'), 'w') as f:
        f.write(conda_config)
        print("The default .condarc file persisted to session containers: \n\n%s" % conda_config)
