#!/opt/continuum/anaconda/envs/lab_launch/bin/python
import json
import os
import sys

PYTHON_PATH = sys.argv[1]
SETTINGS_PATH = '/opt/continuum/project/.vscode/settings.json'

def _dump(settings, SETTINGS_PATH):
    with open(SETTINGS_PATH, 'w') as f:
        json.dump(settings, f)

if os.path.exists(SETTINGS_PATH):
    with open(settings_path, 'r') as f:
        settings = json.load(f)

    if 'python.pythonPath' in settings:
        sys.exit(0)
    else:
        settings['python.pythonPath'] = PYTHON_PATH
        _dump(settings, SETTINGS_PATH)
        print('Python path {} configured in {}'.format(PYTHON_PATH, SETTINGS_PATH))

else:
    os.makedirs(os.path.dirname(SETTINGS_PATH), exist_ok=True)

    settings = {'python.pythonPath': PYTHON_PATH}
    _dump(settings, SETTINGS_PATH)

    print('New settings.json created at {} with Python path {}'.format(SETTINGS_PATH, PYTHON_PATH))
