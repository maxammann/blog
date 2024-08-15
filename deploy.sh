#!/bin/sh

hugo --gc
rsync -r --progress public/ maxammann.org:/var/www/html/
