#!/bin/bash

hugo --gc
rsync -r --progress public/ maxammann.org:~/public_html/ --delete \
    --exclude=/l \
    --exclude=/maplibre-rs
