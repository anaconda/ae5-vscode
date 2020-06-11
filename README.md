# Adding VSCode support to AE5

This repository allows AE5 customers to install VSCode into the AE5
editor container and use it within AE5. When successfully completed, 
VSCode will be made available as an editor selection in AE's dropdown
menus alongside Jupyter, JupyterLab, and Zeppelin.

Unlike the RStudio enhancement, this does not have licensing issues
that require customer installation.

## Manifest

Customization of the VSCode installation is provided through the `manifest.yml`
file. 

The manifest defines the version of [code-server](https://github.com/cdr/code-server) to be installed along with
VSCode extensions. It is recommended that both the [ae5-session](https://github.com/Anaconda-Platform/vscode-ae5-session) and Python extensions are installed.

This repository contains an example file called `manifest.yml.example`. You can
consider the contents as a baseline installation. It is typical for customers to
add more extension to the example manifest along with appropriate post-install
steps.

```yaml
patch_python_extension.py:
  - url: https://ae5-vscode.s3.amazonaws.com/patch_python_extension.py

code-server.tar.gz:
  - url: https://github.com/cdr/code-server/releases/download/3.2.0/code-server-3.2.0-linux-x86_64.tar.gz

extensions:
  - url: https://ae5-vscode.s3.amazonaws.com/ae5-session-0.3.1.vsix

  - url: https://github.com/microsoft/vscode-python/releases/download/2020.4.74986/ms-python-release.vsix
    post_install:
      - "/opt/continuum/anaconda/envs/lab_launch/bin/python patch_python_extension.py /opt/continuum/.vscode/extensions/ms-python.python-2020.4.74986 --preparing-env"
```



## Installation


1. Copy this repository to `/opt/anaconda/vscode` on the AE Master node
    1. If installing on an airgapped system run the `python download.py --archive` first and copy `downloads.tar.gz` along with the repository
1. Run `python build.py` and take note of the name of the Docker image. See below for `build.py` options.
   ```
   sudo gravity enter
   cd /opt/anaconda/vscode
   python build.py --push
   ```
1. Modify the workspace deployment to point to the new image.
    1. `kubectl edit deploy anaconda-enterprise-ap-workspace`
    1. Search for the line containing `name: ANACONDA_PLATFORM_IMAGES_EDITOR`.
    1. Replace the image name with the one created and pushed by `build.py`.
    1. Save and exit the editor.
1. Update the UI configuration to include the VSCode option
    1. Launch a web browser, log into the Op Center, and navigate to the "Configuration" tab.
    1. Edit the `anaconda-enterprise-anaconda-platform.yml` config map
    1. Search for the `anaconda-workspace:` section of this file
    1. Add the VSCode workspace tool so that the section of the file looks like
       ``` 
       anaconda-workspace:
         workspace:
           icon: fa-anaconda
           label: workspace
           url: https://aip.anaconda.com/platform/workspace/api/v1
           options:
             workspace:
               tools:
                 notebook:
                   default: true
                   label: Jupyter Notebook
                   packages: [notebook]
                 jupyterlab:
                   label: JupyterLab
                   packages: [jupyterlab]
                 vscode:
                   label: VSCode
                   packages: [vscode]
                 anaconda-platform-sync:
                   label: Anaconda Project Sync
                   packages: [anaconda-platform-sync]
       ```
    1. Once you have verified the correct formatting, click the "Apply" button.
1. Restart the UI pod
   ```
   kubectl delete pod -l app=ap-ui
   ```

### Build Script
An automated docker build script is provided. It will determine the correct base editor image and apply the suffix `vscode` before starting `docker build`.

```
> python build.py --help
usage: build.py [-h] [--base-editor BASE_EDITOR] [--suffix SUFFIX] [--push]
                [--airgapped]

Build VSCode docker image

optional arguments:
  -h, --help            show this help message and exit
  --base-editor BASE_EDITOR
                        Base editor image name. If not provided the value is
                        computed from the current platform version.
  --suffix SUFFIX       Suffix to apply to base editor image when buidling the
                        VSCode image. Default: vscode
  --push                Push VSCode image if built successfully.
  --airgapped           Run a local webserver to transfer temporary files into
                        the image.
```

Secondly, an airgap install procedure is enabled whereby a `downloads.tar.bz2` can be created using the download script on any machine with internet access. Copying the archive along with this repo into the airgapped master node and using the new `build.py` script will allow non-internet connected systems to install code-server, extensions, and run post-install tasks. 

The `--airgapped` flag launches a local webserver on port 8000 before starting docker build. The Dockerfile build-arg `AIRGAPPED` is set, which will download the `downloads.tar.bz2` file in the RUN layer and remove it when installation has completed.
