import sys
import ruamel_yaml
try:
    with open(sys.argv[1].rstrip('/') + '/anaconda-platform.yml', 'r') as fp:
        envs = ruamel_yaml.safe_load(fp).get('env_specs')
    print('default' if not envs or 'default' in envs else next(iter(envs)))
except Exception as exc:
    print('ERROR: {}'.format(exc), file=sys.stderr)
    print('Could not determine the conda environment; please check anaconda-platform.yml.', file=sys.stderr)
    print('base')
