#!/usr/bin/env python

import argparse
from glob import glob
import json
from os.path import join

def activate_on_start(extension_path):
    package_json = join(extension_path, 'package.json')

    with open(package_json, 'rt') as f:
        pkg = json.load(f)

    ## Python extension will activate when the editor loads
    pkg['activationEvents'].insert(0, 'workspaceContains:**/anaconda-project.yml')

    with open(package_json, 'wt') as f:
        json.dump(pkg, f)


def preparing_env(extension_path):
    ## Indicate that environment is being prepared
    source = join(extension_path, 'out', 'client', 'extension.js')

    with open(source, 'rt') as f:
        js = f.read()

    js = js.replace(' Select Python Interpreter', ' Preparing Environment...')

    with open(source, 'wt') as f:
        f.write(js)


def cli():
    parser = argparse.ArgumentParser(description='Patch the VSCode Python extension.')

    parser.add_argument('extension_path', help='Path to the installed Python extension.')

    parser.add_argument('--auto-start', help='Force the Python extension to start when the session loads.',
                        action='store_true')
    parser.add_argument('--preparing-env', help='Indicate that the environment is being prepared if not found.',
                        action='store_true')

    return parser

def main(args):
    if args.auto_start:
        activate_on_start(args.extension_path)

    if args.preparing_env:
        preparing_env(args.extension_path)

if __name__ == '__main__':
    args = cli().parse_args()

    main(args)
