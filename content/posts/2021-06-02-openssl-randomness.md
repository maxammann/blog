---
layout: post
title: "OpenSSL: Building with Determinisic Randomness"
date: 2021-06-02
slug: openssl-no-random
draft: false
wip: true

keywords: [openssl]
categories: [ security ]
---

TLS, like most cryptographic protocols, depend on random numbers to generate keying material. These numbers should come from a trusted and truly random source.
While this is necessary for production use, for testing purposes it is beneficial to use a pseudorandom number generator (PRNG). By seeding the generator with a static and not-random number, each execution of the protocol yields the same bytes which are sent over the network.

Furthermore, each execution gives the exactly same coverage, if the edges in the implementation of the protocol depend on random values. This is helpful for fuzzing, such that each run yields deterministic results.

OpenSSL internally uses an interface which is called [rand.h](https://www.openssl.org/docs/man1.0.2/man3/rand.html). This API allows setting custom methods for generating random number.

I use this implementation of an OpenSSL random method which is based on the `rand` and `srand` functions of the C standard library.

```c
// based on https://stackoverflow.com/a/7510354
#include <openssl/rand.h>
#include <stdlib.h>

// Seed the RNG. srand() takes an unsigned int, so we just use the first
// sizeof(unsigned int) bytes in the buffer to seed the RNG.
static int stdlib_rand_seed(const void *buf, int num)
{
    if (num < 1)
    {
        srand(0);
        return 0;
    }
    srand(*((unsigned int *) buf));
    return 1;
}

// Fill the buffer with random bytes.  For each byte in the buffer, we generate
// a random number and clamp it to the range of a byte, 0-255.
static int stdlib_rand_bytes(unsigned char *buf, int num)
{
    for (int index = 0; index < num; ++index)
    {
        buf[index] = rand() % 256;
    }
    return 1;
}

static void stdlib_rand_cleanup() {}
static int stdlib_rand_add(const void *buf, int num, double add_entropy)
{
    return 1;
}
static int stdlib_rand_status()
{
    return 1;
}

RAND_METHOD stdlib_rand_meth = { stdlib_rand_seed,
                                 stdlib_rand_bytes,
                                 stdlib_rand_cleanup,
                                 stdlib_rand_add,
                                 stdlib_rand_bytes,
                                 stdlib_rand_status
};
```

By utilizing this random number generator we are able to generate deterministic random numbers. To use this library from Rust we create a public library which sets the above `stdlib_rand_method`:

```c
void make_openssl_deterministic()
{
    RAND_set_rand_method(&stdlib_rand_meth);
}
```

I'm statically linking OpenSSL against my fuzzer which is called `tlspuffin`. That means by utilizing `extern "C"`, we can easily call into C code. 
We can call `make_openssl_deterministic` from Rust and directly seed our random number generator with the number `42`:

```rust
extern "C" {
    pub fn make_openssl_deterministic();
    pub fn RAND_seed(buf: *mut u8, num: c_int);
}

pub fn make_deterministic() {
    warn!("OpenSSL is no longer random!");
    unsafe {
        make_openssl_deterministic();
        let mut seed: [u8; 4] = transmute(42u32.to_le());
        let buf = seed.as_mut_ptr();
        RAND_seed(buf, 4);
    }
}
```

I integrated this functionality into `openssl-src-rs`, which builds OpenSSL using the build system of Rust. If you are interested you can take a look [here](https://github.com/maxammann/openssl-src-rs/blob/fuzz/src/lib.rs#L177).


There is also the C compilation flag: `FUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION` which is used for fuzzing. A quick [search](https://github.com/openssl/openssl/search?q=FUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION) through the OpenSSL code reveals though that the goal of this flag is not to make random number generation deterministic, but change the behavior of OpenSSL for fuzzing. It mostly skips error messages like in [cmp_msg.c](https://github.com/openssl/openssl/blob/3d9d1ce52904660757dadeb629926932abe25158/crypto/cmp/cmp_msg.c#L295). Sadly, there is no official documentation which does into detail what the benefits of using the flag are.
