"""
Script to merge VSCode settings.

Merges administrator settings supplied by admin_settings.json with
settings optionally supplied by a user, either using an AE5 secret or
any other persistent file location (e.g persistent NFS).

Usage:

   merge_vscode_settings.py [<user_settings_file_path>]

The merged JSON file is written to ~/.vscode/User/settings.json

If there is a JSON parse error in either the admin or user settings, the
corresponding error message is written (by default) to
~/.vscode/SETTINGS_PARSE_ERROR
"""

import sys
import os
import json

TOOL_HOME = os.path.abspath(os.path.dirname(__file__))
USER_HOME = os.path.expanduser('~')
DOT_VSCODE = os.path.join(USER_HOME, '.vscode')

admin_settings_path = os.path.join(TOOL_HOME, 'admin_settings.json')
merged_settings_path = os.path.join(DOT_VSCODE, 'User', 'settings.json')
json_error_path = os.path.join(DOT_VSCODE, 'SETTINGS_PARSE_ERROR')
user_settings_path = sys.argv[1] if len(sys.argv) > 1 else None

def _read_json(path, what=None, must_exist=False):
   print('Reading {} settings file: {}'.format(what, path))
   try:
      step = 'reading'
      if not os.path.exists(path):
         raise RuntimeError('file does not exist')
      with open(path, 'r') as fp:
         text = fp.read()
      step = 'parsing'
      return json.loads(text)
   except Exception as exc:
      sev = 'ERROR' if must_exist else 'WARNING'
      msg = '{}: exception {} {} settings file:\n  Path: {}\n  Message: {}\n'.format(sev, step, what, path, exc)
      print(msg, end='')
      try:
         with open(json_parse_error, 'w+') as fp:
            fp.write(msg)
      except Exception:
         pass
      if must_exist:
         sys.exit(-1)

admin_settings = _read_json(admin_settings_path, 'admin', True)
existing_settings = _read_json(merged_settings_path, 'existing', False)
user_settings = _read_json(user_settings_path, 'user', False) if user_settings_path else None

merged_settings = {}
if existing_settings:
   merged_settings.update(existing_settings)
if user_settings:
   merged_settings.update(user_settings)
if admin_settings:
   merged_settings.update(admin_settings)

if existing_settings == merged_settings:
   print('Merged settings unchanged, skipping the write step')
else:
   print('Writing merged settings to %s' % merged_settings_path)
   with open(merged_settings_path, 'w') as f:
      f.write(json.dumps(merged_settings, indent=4, sort_keys=True))
