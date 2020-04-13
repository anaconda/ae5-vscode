"""
Script to merge VSCode settings.

Merges administrator settings supplied by admin_settings.json with
settings optionally supplied by a user, either using an AE5 secret or
any other persistent file location (e.g persistent NFS).

Usage:

   merge_vscode_settings.py <user_settings_file_path>

The merged JSON file is written to /opt/continuum/.vscode/User/settings.json

If there is a JSON parse error in either the admin or user settings, the
corresponding error message is written (by default) to
/opt/continuum/.vscode/SETTINGS_PARSE_ERROR
"""

import sys
import os
import json
import jsonmerge

user_settings_path = sys.argv[1]

OC = "/opt/continuum"
admin_settings_filename = 'admin_settings.json'
json_parse_error_filename = 'SETTINGS_PARSE_ERROR'

admin_settings_path = os.path.join(OC, admin_settings_filename)
merged_settings_path = os.path.join(OC, '.vscode', 'User', 'settings.json')
json_parse_error = os.path.join(OC, '.vscode', json_parse_error_filename)

admin_parse_failure_msg = 'Failed to parse admin settings from {admin_settings_path}'
user_parse_failure_msg = 'Failed to parse user settings from {user_settings_path}'

start_message = ("Merging any available user settings in {user_settings_path} "
                 "into administrator settings in {admin_settings_path} and "
                 "writing to {merged_settings_path}")

print(start_message.format(user_settings_path=user_settings_path,
                           admin_settings_path=admin_settings_path,
                           merged_settings_path=merged_settings_path))

if not os.path.exists(admin_settings_path):
   missing_admin_msg ='Administrator settings file {admin_settings_path} missing.'
   print(missing_admin_msg.format(admin_settings_path=admin_settings_path))

with open(admin_settings_path,'r') as f:
   admin_settings = f.read()

user_settings = None
if os.path.exists(user_settings_path):
   with open(user_settings_path, 'r') as f:
      user_settings = f.read()

try:
   project_json = json.loads(admin_settings)
except JSONDecodeError as e:
   print("Could not parse JSON in %s." % admin_settings_path)
   with open(json_parse_error, 'w') as f:
      f.write(admin_parse_failure_msg.format(admin_settings_path=admin_settings_path))
   sys.exit(1)


invalid_user = False
if user_settings is not None:
   try:
      user_json = json.loads(user_settings)
   except json.JSONDecodeError as e:
      print("WARNING: Invalid JSON supplied by user. Skipping settings merge.")
      with open(json_parse_error, 'w') as f:
         f.write(user_parse_failure_msg.format(user_settings_path))
      invalid_user = True

if (user_settings is None) or invalid_user:
   # Nothing to merge or cannot parse user JSON
   merged_settings = admin_settings
   with open(merged_settings_path, 'w') as f:
      print('Copying workspace settings from %s to %s'
            % (user_settings_path, merged_settings_path))
      f.write(merged_settings)
else:
   merged_json = jsonmerge.merge(project_json, user_json)
   with open(merged_settings_path, 'w') as f:
      print('Writing merged settings to %s' % merged_settings_path)
      f.write(json.dumps(merged_json, indent=4, sort_keys=True))