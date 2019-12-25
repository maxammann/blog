#!/bin/bash

git push
hugo --gc
rsync -r --progress public/ maxammann.org:~/public_html/ --delete --exclude=l
