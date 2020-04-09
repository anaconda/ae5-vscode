#!/bin/sh

echo "un-tagged" > new-file
git add new-file
git commit -m "un-tagged file"

echo "lightweight" > index.html
anaconda-project add-command lw --type unix "python -m http.server 8086"
git add index.html anaconda-project.yml
git commit -m 'lightweight tag'
git tag lw

echo "annotated" > index.html
git add index.html
git commit -m "forgot to tag"

anaconda-project add-command tag --type unix "python -m http.server 8086"
git add anaconda-project.yml
git commit -m "this is annotated"
git tag -a -m "msg" atag

anaconda-project remove-command tag
anaconda-project remove-command lw
git rm index.html
git add anaconda-project.yml
git commit -m "removed commands"

curl -L https://notebooks.anaconda.org/defusco/auto/download -o auto.ipynb
anaconda-project add-command nb --type notebook auto.ipynb
git add auto.ipynb anaconda-project.yml
git commit -m "notebook"
git tag 0.2.0
