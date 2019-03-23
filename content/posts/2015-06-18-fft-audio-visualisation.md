---
layout: post
title: "libav: Visualize audio in a spectrum using libavcodec"
date: 2015-06-18
---

Visualizing audio can be quite complicated if you suffer the mathematical premises. But with some
trial-and-error the final code is not that complicated.

You start by defining a few data structures:

```c
static int16_t left_bands[32]; // Left channel frequency bands
static int16_t right_bands[32]; // Right channel frequency bands

static RDFTContext *ctx; 

static int N, samples; // N and number of samples to process each step
```

The first step is to initialise the FFT library of libav. N is the size of the fft.

```c
void visualize_init(int samples_) {
    samples = samples_;
    N = samples_ / 2; // left/right channels
    ctx = av_rdft_init((int) log2(N), DFT_R2C);
}
```

Let's start now to visualize our buffer:

```c
void buffer_visualize(int16_t *data) {
    int i, tight_index; // just some iterator indices


    float left_data[N * 2];
    float right_data[N * 2];
```

*data* will contain the audio information in an interleaved manner. This means one int left, one int
right, one int left and so on...
So in the next step we're going to split it, convert the integers to floats, apply a window function and write them to our
temporary output buffer.

```c
        int16_t left = data[i];

        double window_modifier = (0.5 * (1 - cos(2 * M_PI * tight_index / (N - 1)))); // Hann (Hanning) window function
        float value = (float) (window_modifier * ((left) / 32768.0f)); // Convert to float and apply

        // cap values above 1 and below -1
        if (value > 1.0) {
            value = 1;
        } else if (value < -1.0) {
            value = -1;
        }
```

Also repeat this for the right channel. Finally we can pass our data to the fft library:

```c
    av_rdft_calc(ctx, left_data);
```

The next part is the real visualizion. You probably want to visualize it in an other way.

```c
    int size = N / 2 * 2; // half is usable, but we have re and im


    for (i = 0, tight_index = 0; i < size; i += size / WIDTH) {

        float im = left_data[i];
        float re = left_data[i + 1];
        double mag = sqrt(im * im + re * re);

        // Visualize magnitude of i-th band
        left_bands[tight_index] = (int16_t) (mag * HEIGHT);


        tight_index++;
    }
```

*The first bin in the FFT is DC (0 Hz), the second bin is Fs / N, where Fs is the sample rate and N is the size of the FFT. The next bin is 2 \* Fs / N.
To express this in general terms, the nth bin is n \* Fs / N.

So if your sample rate, Fs is say 44.1 kHz and your FFT size, N is 1024, then the FFT output bins
are at:*

```
  0:   0 * 44100 / 1024 =     0.0 Hz
  1:   1 * 44100 / 1024 =    43.1 Hz
  2:   2 * 44100 / 1024 =    86.1 Hz
  3:   3 * 44100 / 1024 =   129.2 Hz
  4: ...
  5: ...
     ...
511: 511 * 44100 / 1024 = 22006.9 Hz
```

*Note that for a real input signal (imaginary parts all zero) the second half of the FFT (bins from N / 2 + 1 to N - 1) contain no useful additional information 
(they have complex conjugate symmetry with the first N / 2 - 1 bins). The last useful bin (for practical aplications) is at N / 2 - 1, which corresponds to 22006.9 Hz in the above example. 
The bin at N / 2 represents energy at the Nyquist frequency, i.e. Fs / 2 ( = 22050 Hz in this example), but this is in general not of any practical use, since anti-aliasing filters will 
typically attenuate any signals at and above Fs / 2. (Source: [Stackoverflow](http://stackoverflow.com/a/4371627/1763110))* 

But how to use this after decoding and resampling?
You have to use *AV_SAMPLE_FMT_S16* as output format. So inizialize the resampling library as
follow:

```c
enum AVSampleFormat init_resampling(AVAudioResampleContext **out_resample, AVCodecContext *dec_ctx) {
    AVAudioResampleContext *resample = avresample_alloc_context();

    int64_t layout = av_get_default_channel_layout(dec_ctx->channels);
    int sample_rate = dec_ctx->sample_rate;
    enum AVSampleFormat output_fmt = AV_SAMPLE_FMT_S16;

    av_opt_set_int(resample, "in_channel_layout", layout, 0);
    av_opt_set_int(resample, "out_channel_layout", layout, 0);
    av_opt_set_int(resample, "in_sample_rate", sample_rate, 0);
    av_opt_set_int(resample, "out_sample_rate", sample_rate, 0);
    av_opt_set_int(resample, "in_sample_fmt", dec_ctx->sample_fmt, 0);
    av_opt_set_int(resample, "out_sample_fmt", output_fmt, 0);

    avresample_open(resample);

    *out_resample = resample;

    return output_fmt;
}
```

Then just decode it and pass it to our process function. The normalizing and resampling part can be
quite difficult as it's not that good documented but here's an working example:

```c
// Packet
AVPacket packet;
av_init_packet(&packet);


// Frame
AVFrame *frame = avcodec_alloc_frame();

// Contexts
AVAudioResampleContext *resample = 0;
AVFormatContext *fmt_ctx = 0;
AVCodecContext *dec_ctx = 0;

int audio_stream_index = open_file(file_path, &fmt_ctx, &dec_ctx);

if (audio_stream_index < 0) {
    av_log(NULL, AV_LOG_ERROR, "Error opening file\n");
    return audio_stream_index;
}

// Setup resampling
enum AVSampleFormat output_fmt = init_resampling(&resample, dec_ctx);

visualize_init(4096 / sizeof(int16_t)); // 4096 is the default sample size of libav

while (1) {
    if ((av_read_frame(fmt_ctx, &packet)) < 0) {
        break;
    }

    if (packet.stream_index == audio_stream_index) {
        int got_frame = 0;

        ret = avcodec_decode_audio4(dec_ctx, frame, &got_frame, &packet);
        if (ret < 0) {
            av_log(NULL, AV_LOG_ERROR, "Error decoding audio\n");
            continue;
        }


        if (got_frame) {

            //Normalize the stream by resampling it
            uint8_t *output;
            int out_linesize;
            int out_samples = avresample_get_out_samples(resample, frame->nb_samples);
            av_samples_alloc(&output, &out_linesize, 2, out_samples, output_fmt, 0);

            avresample_convert(resample, &output, out_linesize, out_samples,
                               frame->data, frame->linesize[0], frame->nb_samples);

            buffer_visualize((int16_t *) output);

            av_freep(&output);
        }
    }
}    
```

The example source can be viewed [here](https://gist.github.com/maxammann/137176f1dcd0e4f596e8).
