---
layout: post
title: "Pulseaudio: Synchronize Master and PCM"
published: true
---
*PulseAudio is a network-capable sound server hosted at freedesktop.org. Supported operating systems include Linux, the BSDs, Solaris as well as Microsoft Windows.*

# Problem

I experienced some weird behaviour with my Logitech: Z10 speakers. Sometimes the volume set on the device differed from my pulseaudio setting. Sometimes they just muted. After playing around with **alsamixer** I noticed when modifying the **PCM** channel directly in alsa the volume display updated.

# Solution

I just modified the path file for my sink: **/usr/share/pulseaudio/alsa-mixer/paths/iec958-stereo-output.conf**:

```
[Element IEC958]
switch = mute
```

and added a **Master** element. After merging the **PCM** element with the **Master** element everything seemes to work now.

```
[Element Master]
switch = mute
volume = ignore

[Element PCM]
switch = mute
volume = merge

[Element IEC958]
switch = mute
```

*Note: Master and PCM must be before the actual output element!*
