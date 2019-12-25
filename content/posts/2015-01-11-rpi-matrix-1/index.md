---
layout: post
title: "RPi Matrix #1: Getting this project started!"
date: 2015-01-11
slug: rpi-matrix-1
---

So let's get this project started. My goal is to create some shiny physical device which allows me to display some super awensome stuff, control my desktop computer. Input will be handled by an Android app.

So I looked for same cool way to display suff. I ended up with a 32x32 Led matrix!
Controlling this with a Raspberry Pi worked pretty fine. Luckily there was already a library on github: https://github.com/hzeller/rpi-rgb-led-matrix/

After getting the wiring right:

{{< resourceFigure "DSC05771.JPG" />}}
{{< resourceFigure "DSC05770.JPG" />}}

I saw the first results:

{{< resourceFigure "DSC05763.JPG" />}}

You can even see the display updating by setting a low exposure time!

Next step was to create my own library. Firtly because I don't want to learn C++ right now and probably there's going to be a way to boost performance by running the library in kernel-space (not sure yet).

Other hardware components:

- 32x32 RGB LED Matrix Panel - 4mm Pitch
- Raspberry Pi - Model B
- Rotary Encoder with ugly knob
- MCP23017 
- Some Darlington transistor arrays
- 5V power supply



## What's up next?

Next I'm going to explain how I'm going to control the matrix. Then some font and line rendering. Then I want to wire the matrix library to some higher language (Java/Python). Finally start building the case and combining everything.

Stay tuned!


