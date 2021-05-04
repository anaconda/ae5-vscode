#!/bin/bash
source ~/.bashrc
python_path=`/opt/continuum/anaconda/envs/lab_launch/bin/jq -r '."python.pythonPath"' /opt/continuum/project/.vscode/settings.json`
conda activate $(dirname $(dirname $python_path))
