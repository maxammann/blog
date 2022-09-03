#!/bin/bash

hugo --gc
rsync -r --progress public/ maxammann.org:/var/www/html/ --delete \
    --exclude=/l
