#!/bin/sh

rm -r public/
hugo --gc
rsync -r --progress public/ maxammann.org:/var/www/html/
