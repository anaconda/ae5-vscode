#!/opt/continuum/anaconda/envs/lab_launch/bin/python

'''Inspect git tag. Write an annotated tag as lightweight tag is desired.'''

import argparse
import subprocess
import sys

def cli():
    parser = argparse.ArgumentParser(description='Check and re-write tags')
    parser.add_argument('tag', nargs='?', help='Git tag')
    parser.add_argument('--dry-run', action='store_true', help='Do not rewrite tag. Useful to check for errors.')
    parser.add_argument('-v', '--verbose', action='store_true', help='Print more.')
    return parser


def is_annotated(tag: str):
    '''check that the supplied tag is an "annotated tag"

    Annotated tags are created using

    git tag -a -m <msg> <tag>'''

    ref = subprocess.check_output(f'git cat-file -t {tag}', shell=True).decode().strip()
    return ref == 'tag'


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
        print(f'-- The tag to inspect: {tag}')

    if is_annotated(tag):
        commit = subprocess.check_output(f'git rev-parse $(git rev-parse {tag})^{{}}', shell=True).decode().strip()
        if args.verbose:
            print(f'-- Annotated tag {tag} associated with commit {commit} to replace')

        if not args.dry_run:
            ret = subprocess.check_output(f'git tag -d {tag}', shell=True)
            if args.verbose:
                print(f'-- Annotated tag {tag} deleted.')

            ret = subprocess.check_output(f'git tag {tag} {commit}', shell=True)
            if args.verbose:
                print(f'-- Lightweight tag {tag} created.')
        else:
            sys.exit(0)

if __name__ == '__main__':
    main()

