import os
import sys

PROJECT_DIR = sys.argv[1]

# This function is likely overkill but it is shared with
# ae5-rstudio and ae5-vscode so we're offering the more
# comprehensive search for safety (and it's cheap)

def _ordered_environment_set(pdir):
    env_names = []
    def _add(x):
        if x and x not in env_names:
            env_names.append(x)
    try:
        from anaconda_project.project_info import publication_info
        spec = publication_info(pdir)
        for cspec in spec.get('commands', {}).values():
            _add(cspec.get('env_spec'))
        for ename in spec.get('env_specs', {}).keys():
            _add(ename)
    except Exception as exc:
        print('ERROR: {}'.format(exc), file=sys.stderr)
        print('Could not parse pixi.toml/anaconda-project.yml.', file=sys.stderr)
    root = os.environ.get('CONDA_ROOT')
    if sys.prefix != root:
        _add(sys.prefix)
    _add('base')
    return env_names

print(_ordered_environment_set(PROJECT_DIR)[0])
