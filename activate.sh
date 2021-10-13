source ~/.bashrc
CONDA_DESIRED_ENV=$($CONDA_PYTHON_EXE - <<EOD
import ruamel_yaml
try:
    with open('/opt/continuum/project/anaconda-project.yml', 'r') as fp:
        envs = ruamel_yaml.safe_load(fp).get('env_specs')
    print('default' if not envs or 'default' in envs else next(iter(envs)))
except Exception as exc:
    print('ERROR: {}'.format(exc))
    pass
EOD
)
if [[ "$CONDA_DESIRED_ENV" == ERROR:* ]]; then
    echo $CONDA_DESIRED_ENV
    echo "Could not determine the conda environment; please check anaconda-platform.yml."
    CONDA_DESIRED_ENV=base
fi
conda activate ${CONDA_DESIRED_ENV:-base}
