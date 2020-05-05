#!/usr/bin/env python

import argparse
from http.server import HTTPServer, SimpleHTTPRequestHandler
import os
import subprocess
import threading

def start_server(path, port=8000):
    '''Start a simple webserver serving path on port'''
    os.chdir(path)
    httpd = HTTPServer(('', port), SimpleHTTPRequestHandler)
    httpd.serve_forever()


def docker_build(base_editor, vscode='vscode'):
    vscode_image = '{}-{}'.format(base_editor, vscode)
    subprocess.check_call('docker build --network=host --build-arg WORKSPACE={base_editor} -t {vscode_image} .'
                          .format(base_editor=base_editor, vscode_image=vscode_image))


def cli():
    parser = argparse.ArgumentParser(description='Build VSCode docker image')

    parser.add_argument('--base-editor', help='Base editor image name. If not provided the value is computed from the current platform version.')
    parser.add_argument('--airgapped', help='Run a local webserver to transfer temporary files into the image.')

    return parser


def main(args):
    if args.airgapped:
        daemon = threading.Thread(name='daemon_server',
                                  target=start_server,
                                  args=('downloads')
        daemon.setDaemon(True) # Set as a daemon so it will be killed once the main thread is dead.
        daemon.start()
    
    if args.base_editor:
        base_editor = args.base_editor
    else:
        platform_version = subprocess.check_output('kubectl exec -it `kubectl get pods -l app=ap-ui -o name` -- env | grep PLATFORM_VERSION | awk -NF= "{print $2}"',
                                                   shell=True))
        base_editor = 'leader.telekube.local:5000/ae-workspace:{}'.format(platform_version)
    
    docker_build(base_editor)


if __name__ == '__main__':
    args = cli().parse_args()
    main(args)