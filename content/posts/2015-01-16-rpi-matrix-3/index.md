---
layout: post
title: "RPi Matrix #3: Render vector fonts on a 2D Matrix"
featured_image: /img/matrix/header1.jpg
date: 2015-01-16
slug: rpi-matrix-3
---

Rendering fonts was a pain in the ass! Took me some time to get around with all these
glyphs, transformations and bitmaps. Nonetheless, let's get started!

# Setting up FreeType2

Just include

```cmake
find_package(Freetype)

include_directories(${FREETYPE_INCLUDE_DIRS})
target_link_libraries (_target_ ${FREETYPE_LIBRARIES})
```

and you're ready to go!

# Loading our vector font

For loading I'm going to use the build in font face caching manager. So firt set it up:

```c
FT_Library library;
FTC_Manager manager;

FT_Init_FreeType(library);
FTC_Manager_New(library, 0, 0, 0, face_requester, NULL, manager);
```

face_requester is the method which gets called if a font isn't yet in the cache. PCacheFace is
contains the key information about a font.

```c
typedef struct CacheFace_ {
  const char *file_path;
  int face_index;

} CacheFace, *PCacheFace;

static FT_Error face_requester(FTC_FaceID face_id,
        FT_Library library,
        FT_Pointer req_data,
        FT_Face *aface) {
  PCacheFace face = (PCacheFace) face_id;

  FT_Error error = FT_New_Face(library, face->file_path, face->face_index, aface);
  return error;
}
```
Finally we can get our FT!

```c
FT_Face get_font_face(FTC_ScalerRec *scaler) {
  FT_Size size;
  FT_Error error = FTC_Manager_LookupSize(manager, scaler, &size);

  if (error) {
    return 0; // Font not found or IO error e.g.
  }

  return size->face;
}
```

After building a FTC_ScalerRec :P
Note that we're using the scaler->pixel flag and setting both width and height to size.

```c
CacheFace *cache_face = malloc(sizeof(CacheFace));  // How to fuck do I clear this?
cache_face->face_index = 0;                         // Face to choose
cache_face->file_path = font_file;                  // Path to file

FTC_ScalerRec *scaler = malloc(sizeof(FTC_ScalerRec));

scaler->face_id = cache_face;
scaler->width = size;
scaler->height = size;
scaler->pixel = 1;  

font->scaler = scaler;
```

# Loading glyphs from font face

I really want to use the advantages vector fonts bring. Like [Kerning](https://en.wikipedia.org/wiki/Kerning), which sounds absolutely
awesome. Maybe we can save some space on our small matrix. Challenge: Setting the coordinate origin to the top-left:
{{< resourceFigure "Computer_coordinates_2D.png" "top-left" >}}Source: http://programarcadegames.com/chapters/05_intro_to_graphics/Computer_coordinates_2D.png{{< /resourceFigure >}}

Note: You'll often see something like **>> 6**. A right-bit-shift by 6 is equivalent to dividing
by 64. We need to do this as FreeType uses a 26.6 fixed-point format. When FreeType wants a 16.16 fixed-point format we just shift by 10.

First allocate the variables we're going to use and define our struct:

```c
struct lmString_ {
  signed int height, width;
  FT_Glyph *glyphs;
  int num_glyphs;

  FT_Pos shiftY;    // Highest glyph height

  int use_matrix;  // Use a transformation matrix
};

typedef struct lmString_ lmString;
```


```c
static inline void create_string(lmString *string, FT_ULong *text, int length, lmFont *font) {
  // Get font face
  FT_Error error;
  FT_Face face = get_font_face(...);

  if (face == 0) {
    return;
  }

  FT_GlyphSlot slot = face->glyph;    // a small shortcut
  FT_UInt glyph_index;                // Current glyph
  FT_Long use_kerning;                // Whether our font supports kerning
  FT_UInt previous;                   // The glyph before glyph_index
  int pen_x, pen_y, n;                // Pen position
  FT_Glyph *glyphs = malloc(sizeof(FT_Glyph) * length);  // glyphs table
  FT_Vector pos[length];              // Transformed glyph vectors
  FT_UInt num_glyphs;                 // Num of glyphs

  pen_x = 0;
  pen_y = 0;

  num_glyphs = 0;
  use_kerning = FT_HAS_KERNING(face);
  previous = 0;

  string->shiftY = 0;
```

Let's start now loading each glyph. text[n] is an **unsigned long** with the **FT_LOAD_DEFAULT** settings. If you want
you can choose a specific char set by using **FT_Select_Charmap(face, FT_ENCODING_UNICODE)** for example.

```c
for (n = 0; n < length; n++) {
  glyph_index = FT_Get_Char_Index(face, text[n]);

  error = FT_Load_Glyph(face, glyph_index, FT_LOAD_DEFAULT);
  if (error) {
    continue;
  }
```

Now we come to an interesting part. FreeType usually uses a normal cartesian coordinate system,
but we want our origin at the top-left corder. So we need to find the highest **bearingY** we can find.
{{< resourceFigure "Image3.png" "Glyphs" >}}Source: https://www.freetype.org/freetype2/docs/glyphs/{{< /resourceFigure >}}

*(bearingY is basically the height of a character starting at the origin)*


```c
  FT_Pos bearingY = slot->metrics.horiBearingY >> 6;

  if (string->shiftY < bearingY) {
    string->shiftY = bearingY;
  }
```

Storing the glyph in our "glyph output":

```c
  error = FT_Get_Glyph(face->glyph, &glyphs[n]);

  if (error) {
    continue;
  }
```

If we want to support kerning, we first check if it's supported, not the first character and a
glyph was loaded and calculate our delta X. Then move our pen by this position.

```c
  /* retrieve kerning distance and move pen position */
  if (use_kerning && previous && glyph_index) {
    FT_Vector delta;


    FT_Get_Kerning(face, previous, glyph_index,
    FT_KERNING_DEFAULT, &delta);

    pen_x += delta.x >> 6;
  }
```

Store position in "position output" and go to the next glyph.

```c
  pos[n].x = pen_x;
  pos[n].y = pen_y;

  /* increment pen position */
  pen_x += slot->advance.x >> 6;

  /* record current glyph index */
  previous = glyph_index;

  /* increment number of glyphs */
  num_glyphs++;
}
```

As we want to render a whole string we have to compute a bounding box somehow. You can read
more about this in the [FreeType documentation 4b's compute_string_bbox](http://www.freetype.org/freetype2/docs/tutorial/step2.html#section-4).


```c
static void compute_string_bbox(int num_glyphs, FT_Glyph *glyphs, FT_Vector *pos, FT_BBox *abbox) {
		int n;
		FT_BBox bbox;
		FT_BBox glyph_bbox;


		/* initialize string bbox to "empty" values */
		bbox.xMin = bbox.yMin = 32000;
		bbox.xMax = bbox.yMax = -32000;

		/* for each glyph image, compute its bounding box, */
		/* translate it, and grow the string bbox          */
		for (n = 0; n < num_glyphs; n++) {
				FT_Glyph_Get_CBox(glyphs[n], FT_GLYPH_BBOX_PIXELS,
								&glyph_bbox);

				glyph_bbox.xMin += pos[n].x;
				glyph_bbox.xMax += pos[n].x;
				glyph_bbox.yMin += pos[n].y;
				glyph_bbox.yMax += pos[n].y;

				if (glyph_bbox.xMin < bbox.xMin)
						bbox.xMin = glyph_bbox.xMin;

				if (glyph_bbox.yMin < bbox.yMin)
						bbox.yMin = glyph_bbox.yMin;

				if (glyph_bbox.xMax > bbox.xMax)
						bbox.xMax = glyph_bbox.xMax;

				if (glyph_bbox.yMax > bbox.yMax)
						bbox.yMax = glyph_bbox.yMax;
		}

		/* check that we really grew the string bbox */
		if (bbox.xMin > bbox.xMax) {
				bbox.xMin = 0;
				bbox.yMin = 0;
				bbox.xMax = 0;
				bbox.yMax = 0;
		}

		/* return string bbox */
		*abbox = bbox;
}
```

Last step is to populate our lmString struct.

```c
  // Compute box
  FT_BBox string_bbox;
  compute_string_bbox(num_glyphs, glyphs, pos, &string_bbox);

  string->width = (int) (string_bbox.xMax - string_bbox.xMin);
  string->height = (int) (string_bbox.yMax - string_bbox.yMin);
  string->glyphs = glyphs;
  string->num_glyphs = num_glyphs;
```

# Rendering!

We have now all information we need to render a glyph to a bitmap and copying this
to our matrix buffer.

We start again by defining a few variables.

```c
int n;
FT_Error error;
FT_Glyph image;
FT_Vector pen;
pen.x = 0;
pen.y = 0;

FT_Pos shiftY = string->shiftY;
```

And iterate over all glyphs.

```c
for (n = 0; n < string->num_glyphs; n++) {
  image = string->glyphs[n];
```

Each glyph needs to be transformed now. We also allow an optional matrix
which can rotate each glyph or scale it.

```c
  FT_Vector delta;
  delta.x = x << 6;
  delta.y = -y << 6;


  FT_Matrix *ft_matrix = 0;

  if (string->use_matrix > 0) {
    FT_Matrix m;

    m.xx = string->matrix.xx * 0x10000L; // pixel format to 16.16 fixed float format
    m.xy = string->matrix.xy * 0x10000L;
    m.yx = string->matrix.yx * 0x10000L;
    m.yy = string->matrix.yy * 0x10000L;

    ft_matrix = &m;
  }

  FT_Glyph_Transform(image, ft_matrix, &delta);
```

Each glyph needs to be rendered to a monochrome bitmap in our case, as we want to rasterize
it later on a 2D matrix.

```c
  error = FT_Glyph_To_Bitmap(
  &image,
  FT_RENDER_MODE_MONO,
  &pen,     // Apply pen
  1);       // Do destroy!

  string->glyphs[n] = image;
```

Last step is to copy our bitmap to the matrix. There comes our shiftY, which is the max. bearingY, into play.
We need it to define our top-left corner of our string. Else the lower corner will be used.


```c
  if (!error) {
    FT_BitmapGlyph bit = (FT_BitmapGlyph) image;

    render_bitmap(matrix, bit->bitmap,
    bit->left,
    shiftY - bit->top,
    rgb);

    /* increment pen position --                       */
    /* we don't have access to a slot structure,       */
    /* so we have to use advances from glyph structure */
    /* (which are in 16.16 fixed float format)         */
    pen.x += image->advance.x >> 10;
    pen.y += image->advance.y >> 10;
  }
```


That's it! If you want to view the full source follow [this link](https://github.com/p000ison/rgb-lm/blob/master/src/lm/font.c) with all the matrix rendering stuff.


TODO: Apply rotation matrix to rotate about the origin in the top-left corner.
