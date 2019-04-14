---
layout: post
title: "C: Processing and playing PCMed audio"
date: 2015-03-15
slug: c-process-pcm
---

Playing compressed audio contains can be quiete complicated and needs some process power. So I'm going to start to play **.WAV**, **.AIFF** and raw **PCM** data. 
The first step will be to read a container format and decode the contained audio stream. There are multiple libraries which can do the job for us. For now we'll use [libsndfile](http://www.mega-nerd.com/libsndfile/) because it's simple and supports common FOS audio containers.

For cross-platform playback I'm using libao, which supports alsa and has direct access to the pulseaudio server on linux.

Start by reading a audio container. In this example a **.WAV** file.A

```c
    #include <sndfile.h>

    SF_INFO sfinfo;

    SNDFILE *file = sf_open("test.wav", SFM_READ, &sfinfo);
```

Now initialize our device driver.

```c
    #include <ao/ao.h>

    int default_driver;
    ao_device *device;

    ao_initialize();

    default_driver = ao_default_driver_id();

```

And setup our playback format. We're setting the sample size, then our channels, the audio's sample rate and the supplied byte format.

```c
    ao_sample_format format;
    
    switch (sfinfo.format & SF_FORMAT_SUBMASK) {
        case SF_FORMAT_PCM_16:
            format.bits = 16;
            break;
        case SF_FORMAT_PCM_24:
            format.bits = 24;
            break;
        case SF_FORMAT_PCM_32:
            format.bits = 32;
            break;
        case SF_FORMAT_PCM_S8:
            format.bits = 8;
            break;
        case SF_FORMAT_PCM_U8:
            format.bits = 8;
            break;
        default:
            format.bits = 16;
            break;
    }

    format.channels = sfinfo.channels;
    format.rate = sfinfo.samplerate;
    format.byte_format = AO_FMT_NATIVE;
    format.matrix = 0;
```

Now open our device.

```c
    device = ao_open_live(default_driver, &format, NULL);

    if (device == NULL) {
        fprintf(stderr, "Error opening device.\n");
        return;
    }
```

Then we can decode our complete audio container to a raw pcm format by allocating the needed memory and start the decoding.
The size of the buffer has to be **channels** * **samples** * **sizeof(short**) as we're reading shorts.

```c
    buf_size = (uint_32) (format.channels * sfinfo.frames * sizeof(short));
    buffer = calloc(buf_size, sizeof(char));

    sf_readf_short(file, buffer, buf_size);
```

The last step is the play the buffer and close everything.

```c
    ao_play(device, (char *) buffer, buf_size);

    
    ao_close(device);
    ao_shutdown();
    sf_close(file);
```

[Here's](https://gist.github.com/maxammann/52d6b65b42d8ce23512a) the code with some extras. It includes for example canceling.
