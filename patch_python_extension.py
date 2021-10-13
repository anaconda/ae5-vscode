#!/usr/bin/env python

import sys
import json
from glob import glob
from os.path import abspath, exists, dirname, join

if len(sys.argv) > 1:
    TOOL_HOME = sys.argv[1]
else:
    TOOL_HOME = abspath(dirname(__file__))

print('AE5 Microsoft Python Extension patcher')

extension_glob = join(TOOL_HOME, 'extensions', 'ms-python.python-*')
extension_paths = glob(extension_glob)
if not extension_paths:
    print('Microsoft Python extension not installed; no changes needed.')
    sys.exit(0)

for extension_path in extension_paths:
    package_json = join(extension_path, 'package.json')
    extension_js = join(extension_path, 'out', 'client', 'extension.js')
    if not exists(package_json) and not exists(extension_js):
        continue

    print(extension_path)

    if exists(package_json):
        with open(package_json, 'r') as f:
            data = f.read()
        pkg = json.loads(data)
        patch_str = 'workspaceContains:**/anaconda-project.yml'
        if pkg['activationEvents'][0] != patch_str:
            pkg['activationEvents'].insert(0, patch_str)
            print('- Activation event list ... patching')
            with open(package_json, 'w') as f:
                f.write(json.dumps(pkg))
        else:
            print('- Activation event list ... already patched')

    if exists(extension_js):
        with open(extension_js, 'rt') as f:
            js = f.read()
        js_new = js.replace(' Select Python Interpreter', ' Preparing Environment...')
        if js_new != js:
            print('- Extension messaging ... patching')
            with open(extension_js, 'wt') as f:
                f.write(js_new)
        else:
            print('- Extension messaging ... already patched')
