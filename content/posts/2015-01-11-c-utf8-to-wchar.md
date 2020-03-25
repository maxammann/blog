---
layout: post
title: "C: UTF-8 to wide character"
date: 2015-01-11
slug: c-utf8-to-wchar
---

In my "RPi Matrix" project I wanted to render UTF-8 fonts on a 2D-Raster. To rasterize and vector fonts I used a library called FreeType,
which accepts **unsigned long*** as input to render a single character. So I had to get the (uni-)codes for each character from my string.
The confusion already started with the [difference between UTF-8 and unicode][unicode-utf]. So my conclusion was I had to convert UTF-8 to
some other encoding. Probably some encoding which supports one long (or wchar_t) per character.

The problem even get's bigger if you want cross-platform support. On the Linux side you have **[iconv][iconv_open]**. On windows you have some ugly **MultiByteToWideChar(...)** function.
Luckily I only have to support Linux.

So let's get started with some code:

```c
#define UTF8_BUFERR_SIZE  256;

static wchar_t *utf8towchar(char* utf8) {
  wchar_t *text=malloc (UTF8_BUFERR_SIZE * sizeof(wchar_t));
  char *output = (char *) text;

  gchar *input = g_strdup(utf8);                // get length of utf-8 string
  gchar *def_copy = input;

  iconv_t foo = iconv_open("WCHAR_T", "UTF-8"); // Convert UTF-8 to WCHAR_T
  size_t ibl = strlen(input);                   // Input length
  size_t obl = UTF8_BUFERR_SIZE;                // Max output length
  iconv(foo, &input, &ibl, &output, &obl);
  iconv_close(foo);

  g_free(def_copy);

  return text;
}
```

*Note: the wchar_t array has to be freed!*


Now convert the **wchar_t** array to a **unsigned long** array and pass each long to the FreeType function **FT_Get_Char_Index(face, c);**.


[iconv_open]: https://www.gnu.org/savannah-checkouts/gnu/libiconv/documentation/libiconv-1.13/iconv_open.3.html#DESCRIPTION
[unicode-utf]: http://www.rrn.dk/the-difference-between-utf-8-and-unicode
