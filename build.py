#!/usr/bin/env python

import argparse
from http.server import HTTPServer, SimpleHTTPRequestHandler
import os
import subprocess
import threading

def start_server(path, port=8000):
    '''Start a simple webserver serving path on port'''
    os.chdir(path)
    print("Starting localhost server on port {}".format(port))
    httpd = HTTPServer(('', port), SimpleHTTPRequestHandler)
    httpd.serve_forever()


def docker_build(base_editor, suffix='vscode', push=False, airgapped=False):
    vscode_image = '{}-{}'.format(base_editor, suffix)

    build_args = [
        "--build-arg WORKSPACE={}".format(base_editor)
    ]

    if airgapped:
        build_args.append('--build-arg AIRGAPPED=TRUE')

    cmd = ("docker build --no-cache --network host {build_args} -t {vscode_image} ."
            .format(build_args=' '.join(build_args), vscode_image=vscode_image)
          )
    print(cmd)

    subprocess.check_call(cmd, shell=True)

    if push:
        subprocess.check_call('docker push {}'.format(vscode_image), shell=True)


def cli():
    parser = argparse.ArgumentParser(description='Build VSCode docker image')

    parser.add_argument('--base-editor', help='Base editor image name. If not provided the value is computed from the current platform version.')
    parser.add_argument('--suffix', help='Suffix to apply to base editor image when buidling the VSCode image. Default: vscode',
                        type=str, default='vscode')
    parser.add_argument('--push', help='Push VSCode image if built successfully.', action='store_true')
    parser.add_argument('--airgapped', help='Run a local webserver to transfer temporary files into the image.',
                        action='store_true')

    return parser


def main(args):
    if args.airgapped:
        if not os.path.exists('downloads.tar.bz2'):
            raise RuntimeError('The downloads.tar.bz2 file is missing')

        daemon = threading.Thread(name='daemon_server',
                                  target=start_server,
                                  args=('.',))
        daemon.setDaemon(True) # Set as a daemon so it will be killed once the main thread is dead.
        daemon.start()
    
    if args.base_editor:
        base_editor = args.base_editor
    else:
        platform_version = subprocess.check_output('kubectl exec -it `kubectl get pods -l app=ap-ui -o name` -- env | grep PLATFORM_VERSION',
                                                   shell=True)
        base_editor = 'leader.telekube.local:5000/ae-editor:{}'.format(platform_version.decode().strip().split('=')[1])
    
    docker_build(base_editor, args.suffix, args.push, args.airgapped)


if __name__ == '__main__':
    args = cli().parse_args()
    main(args)

