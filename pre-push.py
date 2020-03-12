#!/opt/continuum/anaconda/envs/lab_launch/bin/python

'''git pre-push script for Anaconda Enterprise

This script can act as the .git/hook/pre-push script itself
or be called by it.'''

import argparse
import configparser
import json
import os
import requests
import subprocess
import sys

from anaconda_project.project import Project
from pprint import pprint

VERSIONS_URL = f'{os.environ["TOOL_PROJECT_URL"]}/versions'


def cli():
    parser = argparse.ArgumentParser(description='POST revision metadata')
    parser.add_argument('tag', nargs='?', help='Git tag')
    parser.add_argument('--dry-run', action='store_true', help='Do not POST the metadata. Useful to check for errors.')
    parser.add_argument('-v', '--verbose', action='store_true', help='Print more.')
    return parser


def main(cli_args: list = None):
    if cli_args is not None:
        args = cli().parse_args(cli_args)
    else:
        args = cli().parse_args()


    if args.verbose:
        print(f'-- Parsed arguments: {args}')

    # Determine the tag to POST
    if args.tag is None:
        # find the most recent tag
        tag = subprocess.check_output('git describe --tags --abbrev=0', shell=True).decode().strip()
    else:
        tag = args.tag

    if args.verbose:
        print(f'-- The tag to POST: {tag}')

    # borrow token from .git/config
    config = configparser.ConfigParser(strict=False)
    config.read('/opt/continuum/project/.git/config')
    _,bearer_token = config['http']['extraHeader'].split(':')

    headers = {
        'Authorization': bearer_token.strip(),
        'Content-Type': 'application/vnd.api+json'
    }

    if args.verbose:
        print(f"""-- Retrieved bearer token from .git/config
{headers}
""")

    if args.verbose:
        print(f'-- Project version URL: {VERSIONS_URL}')
        print(f"-- Checking if {tag} has already been posted")

    ## to avoid conflicts later get the previously
    ## post tags (either from UI or this script)
    res = requests.get(VERSIONS_URL, headers=headers)
    res.raise_for_status()
    versions = [v['id'] for v in res.json()['data']]

    if args.verbose:
        print(f"""-- Known version tags
{versions}
""")

    ## If the tag already posted ignore exit
    ## since there may be new un-tagged commits
    ## in this git push.
    if tag in versions:
        if args.verbose:
            print(f'-- Tag {tag} has already been created.')
            print(f'-- Silent termination.')
        sys.exit(0)

    project = Project('.')
    body = {'data':{'type':'version','attributes':{'name':tag,'metadata':project.publication_info()}}}

    if args.verbose:
        print('-- The metadata to be posted:')
        pprint(body)
        print(body)

    if not args.dry_run:
        res = requests.post(VERSIONS_URL, headers=headers, data=json.dumps(body))

        if args.verbose:
            print(f"""-- POST request returned
{res}
{res.reason}
""")

        res.raise_for_status()

    else:
        print(f""" -- Dry Run POST request
requests.post({VERSIONS_URL},
              headers={headers},
              data={json.dumps(body)}
""")

if __name__ == '__main__':
    main()

