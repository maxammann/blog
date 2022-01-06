---
layout: post
title: "Streaming JSON Data in Python"
date: 2022-01-06
slug: python-streaming-json
draft: false
wip: false

resources:
- src: "*.png"
- src: "*.jpg"

keywords: [ python, json, parsing ]
categories: [ ]
---

[RFC 7464](https://datatracker.ietf.org/doc/html/rfc7464) defines a text file format based on the popular JSON format. Its intention is to write JSON texts as a sequence delimited by some character. This can be especially helpful for structured logging using JSON. If you want to write JSON objects instead of plain text with each log entry, then you need some streaming file format.
This means instead of overwriting a log file over and over you want to be able to just append to a file on disk.

Sadly, [RFC 7464](https://datatracker.ietf.org/doc/html/rfc7464) is only a draft, which means that implementations which support streaming JSON values deviate from the specification.

## Why is JSON not sufficient?

With JSON this not easily possible by default. The reason is that in order to write a sequence you have to stick with JSON arrays.
Arrays start with a `'['`, then data follows, and finally the array is ended with a `']'`.
This means when you start a log file a JSON writer initially has to write a `'['`. When the application stops the writer has to write a `']'`, in order to yield a syntactically correct JSON file. Several issues arise here:

* How do we handle abrupt application crashes? How do we take care that the JSON log file is syntactically correct?
* How do we append new data when the application starts next?

## How can we write streaming JSON in Python?

Writing a stream of JSON objects is quite simple. In order to append to a streaming JSON file we just open it in append-mode and write a prefix and postfix control character like specified in [RFC 7464](https://datatracker.ietf.org/doc/html/rfc7464).

```python
import json
with open('file.json','a') as f:
    f.write(json.dumps({'bar': ('baz', None, 1.0, 2)}))
    f.write("\u000a")
```

Note: `yajl` is not able to handle Record Separators (`\u001e`) like specified in [RFC 7464](https://datatracker.ietf.org/doc/html/rfc7464). Therfore, we do not write it here.

## How can we parse streaming JSON in Python?

Parsing such a file is more complicated in python, because the whole streaming JSON file is not a valid JSON file anymore. To my knowledge the only library which supports parsing such a structure efficiently is [jsonslicer](https://pypi.org/project/jsonslicer/) which uses the C library [yajl](https://lloyd.github.io/yajl/) under the hood. `jsonslicer` offers an easier to use API in my opinion.
This library reads one byte at a time and emits JSON objects one after the other without loading the whole file into memory. First install `jsonslicer` using pip for example:

```bash
pip install jsonslicer
```

```python
from jsonslicer import JsonSlicer
with open('file.json') as f:
    for data in JsonSlicer(f, (), 
        yajl_allow_multiple_values=True, 
        yajl_allow_partial_values=True, 
        yajl_allow_trailing_garbage=True):
        print(data)
```

* The flag `yajl_allow_multiple_values` is essential here. It instructs `yajl` to continue parsing after an initial JSON value was processed.
* The flag `yajl_allow_trailing_garbage` allows non-JSON text at the end of the file. 
* The flag `yajl_allow_partial_values` avoids errors when parsing a line like this: `{"bar": ["baz", null, 1.0, 2]` (Note the missing closing bracket). 

Note: `yajl` is not able to handle Record Separators (`\u001e`) like specified in [RFC 7464](https://datatracker.ietf.org/doc/html/rfc7464).
