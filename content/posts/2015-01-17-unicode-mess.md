---
layout: post
title: "Unicode: Mess with characters and fonts."
date: 2015-01-17
slug: unicode-mess
---

Can you see this symbol? 🔊 Nice, this means you have a good set of fonts and a good browser.
Mostly easy so view a good part of the Unicode Character Set. But when it comes to
support these in your own programs it can be a hassle to render these.

The FreeType library supports rending basically every character but still, it can be
quite complicated if you're not into the encoding of strings. First you'll want to
set the charset FreeType should use if it isn't already specified in the font file by using **FT\_Select\_Charmap(face, FT\_ENCODING\_UNICODE)**.
You can also get [some information](http://www.freetype.org/freetype2/docs/reference/ft2-base_interface.html#FT_FaceRec) about the charset tables in your font or
set the one you want to use.

FreeType supports quite a bunch of charsets
*(I'm not sure why FreeType calls it's charsets encodings, as encodings are something very different)*:

|Charset|
|---|
|FT\_ENCODING\_NONE|
|FT\_ENCODING\_UNICODE|
|FT\_ENCODING\_MS\_SYMBOL|
|FT\_ENCODING\_ADOBE\_LATIN\_1|
|FT\_ENCODING\_OLD\_LATIN\_2|
|FT\_ENCODING\_SJIS|
|FT\_ENCODING\_GB2312|
|FT\_ENCODING\_BIG5|
|FT\_ENCODING\_WANSUNG|
|FT\_ENCODING\_JOHAB|
|FT\_ENCODING\_ADOBE\_STANDARD|
|FT\_ENCODING\_ADOBE\_EXPERT|
|FT\_ENCODING\_ADOBE\_CUSTOM|
|FT\_ENCODING\_APPLE\_ROMAN|

**FT\_ENCODING\_UNICODE** is probably the one you want to use. Also, if you want won't be able to include the 🔊 character like this:

```c
NEW_STRING("🔊");
```

or:

```c
NEW_WSTRING(L"🔊");
```


You'll have to do something like this to be sure that it works on every system:

```c
unsigned long speaker = 0x1F50A;
NEW_LONG_STRING(&speaker);
```



Now let's find a font which supports the following characters: 🔊 (0x1F50A), ☁ (0x2601) and ⏰ (0x23F0)

## [Symbola](http://users.teilar.gr/~g1951d/)

The only font which supports all three characters I've found.

## [Google Noto](https://www.google.com/get/noto/)

Awesome font by Google. Supported ☁ and ⏰. But didn't support 🔊. Probably because it's beyond 0xFFFF.

## Arial Unicode

Should have been working, but didn't.
