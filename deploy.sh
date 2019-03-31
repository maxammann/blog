#!/bin/bash

git push
hugo
rsync -r --progress public/ maxammann.org:~/public_html/
