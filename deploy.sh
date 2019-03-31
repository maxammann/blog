#!/bin/bash

hugo
rsync -r --progress public/ maxammann.org:~/public_html/
