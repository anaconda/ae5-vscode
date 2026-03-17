import sys
try:
    import ruamel_yaml as yaml_loader
except ModuleNotFoundError:
    import yaml as yaml_loader
try:
    with open(sys.argv[1].rstrip('/') + '/anaconda-project.yml', 'r') as fp:
        envs = yaml_loader.safe_load(fp).get('env_specs')
    print('default' if not envs or 'default' in envs else next(iter(envs)))
except Exception as exc:
    print('ERROR: {}'.format(exc), file=sys.stderr)
    print('Could not determine the conda environment; please check anaconda-project.yml.', file=sys.stderr)
    print('base')
