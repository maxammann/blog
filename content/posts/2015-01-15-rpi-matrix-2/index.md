---
layout: post
title: "RPi Matrix #2: C!"
featured_image: /img/matrix/header1.jpg
date: 2015-01-15
slug: rpi-matrix-2
---
Next step is going to be to find a way to render stuff on our matrix!

# Data structures

## Register output: io-bits
*(For RPi Model B Rev2)*

```c
union io_bits {
  struct {
    bits_t unused : 2;              // 0-1
    bits_t output_enable_rev2 : 1;  // 2
    bits_t clock_rev2  : 1;         // 3
    bits_t strobe : 1;              // 4
    bits_t unused2 : 2;             // 5..6
    bits_t row : 4;                 // 7..10
    bits_t unused3 : 6;             // 11..16
    bits_t r1 : 1;                  // 17
    bits_t g1 : 1;                  // 18
    bits_t unused4 : 3;
    bits_t b1 : 1;                  // 22
    bits_t r2 : 1;                  // 23
    bits_t g2 : 1;                  // 24
    bits_t b2 : 1;                  // 25
    } bits;

    uint32_t raw;
};
```

The size of this struct is 26 → less than 32 so we can use a 32-bit integer to define our register output.

{{< resourceFigure "GPSET0_Location.png" "Table about RPI GPIOs" >}}Source: http://www.pieter-jan.com/images/RPI_LowLevelProgramming/GPSET0_Location.png{{< /resourceFigure >}}

The register we're going to write the struct into is the has the address 0x001C. *(Note: You first need to write to the 0x0028 register to clear the GPIO pins first)*


## Bit-planes
The data is going to be organized a bit-plane of io\_bits. The bit-plane contains **colums** times **double-row**
io\_bit structs. *(Double-rows is the amount of rows divided by 2.)*

This is because if you have a matrix with 32 rows for example you are going to have to address the rows
by 4 bits. \\(2^4\\) is 16, which is \\(32 / 2\\). For a 16 pixels high matrix you have a 3 bit address: \\(16 / 2 = 2^3\\). A 32 pixels high
matrix is basically a matrix of two 16x32 forged together. If we want to control the upper part we need to set **R1,G1,B1**. For the lower part: **R2,G2,B2**.
That's why we only need half the space for our bit-plane. The io\_bits struct just contains more information than obvious.

On the raspberry's hardware we're going to use 11 bit-planes. More details later.

# Filling our bit-planes

We're going to iterate over all bit-planes we want to fill. Then we're going to check if we want to turn the R, G or B output on.
Now just set the output's we need and copy the data to each double-row and column.


```c

const uint16_t red = map_color(matrix, rgb->r);
const uint16_t green = map_color(matrix, rgb->g);
const uint16_t blue = map_color(matrix, rgb->b);

//Iterate over bit-planes
for (i = MAX_BITPLANES - matrix->pwm_bits; i < MAX_BITPLANES; ++i) {
  // The bit we check in our color
  int mask = 1 << i;

  int r = (red & mask) == mask; // Check if i-th bit in red is set
  int b = (blue & mask) == mask; // Check if i-th bit in blue is set
  int g = (green & mask) == mask; // Check if i-th bit in green is set

  io_bits plane_bits = { 0 };
  plane_bits.bits.r1 = plane_bits.bits.r2 = (bits_t) r;
  plane_bits.bits.g1 = plane_bits.bits.g2 = (bits_t) g;
  plane_bits.bits.b1 = plane_bits.bits.b2 = (bits_t) b;

  for (row = 0; row < double_rows; ++row) { // Iterate over all double-rows
    io_bits *row_data = lm_io_bits_value_at(bitplane, columns, row, 0, i);
    for (col = 0; col < columns; ++col) { // Iterate over all columns
      (row_data++)->raw = plane_bits.raw; // Copy data
    }
  }
}
```

We're creating **matrix->pwm_bits** io\_bits. Because the more io\_bits we use the more we're going to PWM our LEDs.
More data → greater color-depth.More on this later.

# Throw this data at our matrix!

First prepare some masks we're going to need later on.

```c
io_bits color_clock_mask = { 0 };   // Mask of bits we need to set while clocking in.
io_bits clock = { 0 }, output_enable = { 0 }, strobe = { 0 }, row_address = { 0 };
io_bits row_mask = { 0 };

// Color & clock
color_clock_mask.bits.r1 = color_clock_mask.bits.g1 = color_clock_mask.bits.b1 = 1;
color_clock_mask.bits.r2 = color_clock_mask.bits.g2 = color_clock_mask.bits.b2 = 1;
SET_CLOCK(color_clock_mask.bits, 1);

// Row mask
row_mask.bits.row = 0x0f;

// Clock
SET_CLOCK(clock.bits, 1);

// EO
ENABLE_OUTPUT(output_enable.bits, 1);

// Strobe
strobe.bits.strobe = 1;
```

We start by iterating over all double-rows.

```c
for (d_row = 0; d_row < double_rows; ++d_row) {
```

Now we're setting our current row address which basically is our iteration value *d_row*.
*(Apply bit mask as we really only want to send the address which is max 0xF)*

```c
  row_address.bits.row = d_row;
  lm_gpio_set_masked_bits(row_address.raw, row_mask.raw);  // Set row address
```

Start PWM-ing our LEDs! We start at *COLOR_SHIFT*, which is *MAX_BITPLANES - CHAR_BIT*,
since the first 3 PWM loops are basically useless as the raspberry can't time that precisely.
Still the wither *pm_bits*, the more often we need to iterate.

```c
  for (b = COLOR_SHIFT + MAX_BITPLANES - pwm_bits; b < MAX_BITPLANES; ++b) {
```

Get the row data for our current *d_row* for column 0, iterate over all columns, write **R1,G1,B1** and **R2,G2,B2** and clock the color in.

```c
    io_bits *row_data = lm_io_bits_value_at(bitplane, columns, d_row, 0, b);

    for (col = 0; col < columns; ++col) {
      const io_bits out = *row_data++;
      lm_gpio_set_masked_bits(out.raw, color_clock_mask.raw);
      lm_gpio_set_bits(clock.raw);
    }
```

Clock back to normal.

```c
    lm_gpio_clear_bits(color_clock_mask.raw);
```

Strobe in current row.

```c
    lm_gpio_set_bits(strobe.raw);
    lm_gpio_clear_bits(strobe.raw);
```

The last step is to sleep for a specific amount of time.

```c
    sleep_nanos(sleep_timings[b]);
```

One loop is finished now, repeat this now as fast as possible

```c  
  }
}
```

## Raspberry: "How long do I need to wait?"

The code to generate the timings is as follows:

```c
long base_time_nanos = 200;
long row_sleep_timings[MAX_BITPLANES];

for (i = 0; i < MAX_BITPLANES; ++i) {
  row_sleep_timings[i] = (1 << i) * base_time_nanos;
}
```

which will output *(Credits go to https://github.com/hzeller/rpi-rgb-led-matrix)*:

```c
row_sleep_timings[0]: (1 * base_time_nanos)
row_sleep_timings[1]: (2 * base_time_nanos)
row_sleep_timings[2]: (4 * base_time_nanos)
row_sleep_timings[3]: (8 * base_time_nanos)
row_sleep_timings[4]: (16 * base_time_nanos)
row_sleep_timings[5]: (32 * base_time_nanos)
row_sleep_timings[6]: (64 * base_time_nanos)
row_sleep_timings[7]: (128 * base_time_nanos)
row_sleep_timings[8]: (256 * base_time_nanos)
row_sleep_timings[9]: (512 * base_time_nanos)
row_sleep_timings[10]: (1024 * base_time_nanos)
```


# Accessing individual pixels

```c
uint16_t x, uint16_t y;

io_bits *bits = lm_io_bits_value_at(matrix->hot_bitplane_buffer, matrix->columns, y & matrix->row_mask, x, min_bit_plane);
if (y < double_rows) { // Top
  for (i = min_bit_plane; i < MAX_BITPLANES; ++i) {
    int mask = 1 << i;

    bits->bits.r1 = (bits_t) ((red & mask) == mask);
    bits->bits.g1 = (bits_t) ((green & mask) == mask);
    bits->bits.b1 = (bits_t) ((blue & mask) == mask);
    bits += columns;
  }
} else { // Bottom
  for (i = min_bit_plane; i < MAX_BITPLANES; ++i) {
    int mask = 1 << i;
    bits->bits.r2 = (bits_t) ((red & mask) == mask);
    bits->bits.g2 = (bits_t) ((green & mask) == mask);
    bits->bits.b2 = (bits_t) ((blue & mask) == mask);
    bits += columns;
  }
}
```

Basically we're doing the same, except that we bitwise AND **y** and **double_rows - 1**. So **16** and **32** becomes **0**, **6** and **16+6** becomes 6.
Furthermore we're modifying only the io\_bits with correspond to our x value.
