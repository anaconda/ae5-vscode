"""
Script to merge VSCode settings.

Merges administrator settings supplied by admin_settings.json with
settings optionally supplied by a user, either using an AE5 secret or
any other persistent file location (e.g persistent NFS).

User settings mode:
   merge_vscode_settings.py user [<user_settings_file_path>]
   Merges /tools/vscode/admin_settings.json with user settings
   The merged JSON file is written to ~/.vscode/User/settings.json
Project settings mode:
   merge_vscode_settings.py project [<python_path>]
   Modifies the python.defaultInterpreterPath setting for the project
   The merged JSON file is written to ~/project/.vscode/settings.json

If there is a JSON parse error in either mode, the corresponding error
message is written to ~/.vscode/SETTINGS_PARSE_ERROR
"""

import json
import sys
import os

TOOL_HOME = os.path.abspath(os.path.dirname(__file__))
USER_HOME = os.path.expanduser('~')
DOT_VSCODE = os.path.join(USER_HOME, '.vscode')

json_error_path = os.path.join(DOT_VSCODE, 'SETTINGS_PARSE_ERROR')

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


def _write_if(existing_settings, merged_settings, merged_settings_path):
   if existing_settings == merged_settings:
      print('Merged settings unchanged, skipping the write step')
   else:
      print('Writing merged settings to %s' % merged_settings_path)
      with open(merged_settings_path, 'w') as f:
         f.write(json.dumps(merged_settings, indent=4, sort_keys=True))


def merge_user_settings(user_settings_path=None):
   admin_settings_path = os.path.join(TOOL_HOME, 'admin_settings.json')
   merged_settings_path = os.path.join(DOT_VSCODE, 'settings.json')

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

   _write_if(existing_settings, merged_settings, merged_settings_path)


def merge_python_path(python_path):
   merged_settings_path = os.path.join(USER_HOME, 'project', '.vscode', 'settings.json')

   existing_settings = _read_json(merged_settings_path, 'existing', False)

   merged_settings = {}
   if existing_settings:
      merged_settings.update(existing_settings)
   if python_path:
      merged_settings['python.defaultInterpreterPath'] = '{}/bin/python'.format(python_path)

   _write_if(existing_settings, merged_settings, merged_settings_path)


if __name__ == '__main__':
   first_arg = sys.argv[1] if len(sys.argv) > 1 else None
   second_arg = sys.argv[2] if len(sys.argv) > 2 else None
   if first_arg == 'user':
      merge_user_settings(second_arg)
   elif first_arg == 'project':
      merge_python_path(second_arg)
   else:
      print('ERROR: unexpected usage: {}'.format(' '.join(sys.argv)))
      sys.exit(-1)
