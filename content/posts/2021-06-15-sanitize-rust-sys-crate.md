---
layout: post
title: "Rust: Enable AddressSanitizer in Rust *-sys crate"
date: 2021-06-15
slug: sanitize-rust-sys-crate
draft: false
wip: true

keywords: [openssl]
categories: [rust]
---

For our tlspuffin fuzzer we use Rust to implement the testing harness. The harness is statically linked to OpenSSL via the [openssl-sys](https://github.com/sfackler/rust-openssl/) and 
[openssl-src](https://github.com/alexcrichton/openssl-src-rs) crates, where the latter just provides a [Rust Build Script](https://doc.rust-lang.org/cargo/reference/build-scripts.html). `openssl-sys` runs the script, then looks at the build artifacts and statically links against them.

This is a usual setup when working with C libraries in Rust. How do we enable the wildly known [AddressSanitizer](https://clang.llvm.org/docs/AddressSanitizer.html)? 

## 1. Use Clang

The first step is to make the build script for OpenSSL use Clang. While GCC also supports sanitizers, Clang has a greater selection of available sanitizers. For example the [SanitizerCoverage](https://clang.llvm.org/docs/SanitizerCoverage.html) sanitizer is only available in Clang.

This can be done by setting the `CC` environment variable:

```rust
let mut configure = ...;
configure.arg("./Configure");
configure.env("CC", "clang");
```

Note: `configure` is an instance of `std::process::Command` which runs the `./Configure` script with various arguments.


# 2. Usage of -fsanitize=address

The next step is to append `-fsanitize=address` flag to the invocation of the compiler. For OpenSSL we can do this by adding the `enable-asan` option. 

```rust
if cfg!(feature = "asan") {
    configure.arg("enable-asan");
}
```

An other way of doing this is by appending the `sanitize` option directly to the `CC` variable.


```rust
let mut cc = "clang".to_owned();

if cfg!(feature = "asan") {
    cc.push_str(" -fsanitize=address");
}

configure.env("CC", cc);
```


## 3. Link AddressSanitizer Runtime

The AddressSanitizer requires a runtime. 
The previous step instruments the library and adds calls into this runtime. This means the linker is responsible for adding this runtime. Therefore, `-fsanitize=address` is not only accepted by the compiler but also the linker. While it is possible pass `-lasan` to the linker, it is not recommended. The AddressSanitizer, which is also known as `libasan` must be the first library in the initial library list. That means it must have the possibility to overwrite function calls in other dynamically loaded libraries. The reason for this is that it needs to have control over calls to `malloc` or `free` to detect memory issues like null pointer dereferences.

### -static-libsan vs -shared-libsan

There are two ways to instrument the library and link `libasan`. The two options `-static-libsan` and `-shared-libsan` are mentioned in the [command line reference](https://clang.llvm.org/docs/ClangCommandLineReference.html).

Clang uses `-static-libsan` as default whereas GCC uses `-shared-libsan` as default. The advantages and disadvantage of either are documented [here](https://github.com/google/sanitizers/wiki/AddressSanitizerAsDso).

In our example there is actually only one possibility. We want to instrument the library, but do not want to instrument the executable which calls into the static library. If we want to sanitize the whole Rust executable, including OpenSSL we can simply use the unstable Rust feature [Sanitizers Support](https://rustc-dev-guide.rust-lang.org/sanitizers.html) to link against the `libasan` runtime.

If we use `-static-libsan` the compiled static library of OpenSSL will have many undefined references the functions of the runtime. These need to be resolved during the final linking which `rustc` does. Same goes for `-shared-libsan` in our case. There will be undefined references.

Therefore, for our usecase there is no practical difference beween these two options, as we have to use the linker provided by `rustc`.

### Methods for Linking `libasan`

There are two ways. Either we tell `rustc` directly to link to `libasan` 

```bash
RUSTFLAGS="-C link-arg=-lasan"
```

The other way it to do this using the directive `cargo:rustc-link-lib` in the build script of OpenSSL:

```rust
if cfg!(feature = "asan") {
    configure.arg("enable-asan");
    println!("cargo:rustc-link-lib=asan");
}
```

An unanswered question is how to control in which order `rustc` links against shared libraries. If `libasan` is not the first in the list then the executable will abort with:

```bash
==465915==ASan runtime does not come first in initial library list; you should either link runtime to your application or manually preload it with LD_PRELOAD.
```


If using the `RUSTFLAGS`, then the linker produces the following:

```bash
ldd target/debug/bin
    linux-vdso.so.1 (0x00007ffec712f000)
    libgcc_s.so.1 => /usr/lib/libgcc_s.so.1 (0x00007f609c6f2000)
    librt.so.1 => /usr/lib/librt.so.1 (0x00007f609c6e7000)
    libpthread.so.0 => /usr/lib/libpthread.so.0 (0x00007f609c6c6000)
    libm.so.6 => /usr/lib/libm.so.6 (0x00007f609c582000)
    libdl.so.2 => /usr/lib/libdl.so.2 (0x00007f609c57b000)
    libc.so.6 => /usr/lib/libc.so.6 (0x00007f609c3af000)
    /lib64/ld-linux-x86-64.so.2 => /usr/lib64/ld-linux-x86-64.so.2 (0x00007f609f992000)
    libasan.so.6 => /usr/lib/libasan.so.6 (0x00007f609b9ce000)
    libstdc++.so.6 => /usr/lib/../lib/libstdc++.so.6 (0x00007f609b7b8000)
```
Note, that the `libasan` is at the very bottom. When linking using the build script, `rustc` did link correctly:

```bash
ldd target/debug/bin
    linux-vdso.so.1 (0x00007fffe93e5000)
    libasan.so.6 => /usr/lib/libasan.so.6 (0x00007f633b05d000)
    libgcc_s.so.1 => /usr/lib/libgcc_s.so.1 (0x00007f633b042000)
    librt.so.1 => /usr/lib/librt.so.1 (0x00007f633b037000)
    libpthread.so.0 => /usr/lib/libpthread.so.0 (0x00007f633b016000)
    libm.so.6 => /usr/lib/libm.so.6 (0x00007f633aed2000)
    libdl.so.2 => /usr/lib/libdl.so.2 (0x00007f633aecb000)
    libc.so.6 => /usr/lib/libc.so.6 (0x00007f633acfd000)
    libstdc++.so.6 => /usr/lib/../lib/libstdc++.so.6 (0x00007f633aae7000)
    /lib64/ld-linux-x86-64.so.2 => /usr/lib64/ld-linux-x86-64.so.2 (0x00007f633e484000)
```
Note, that the `libasan` is at the very top.

One way to control it is to use `LD_PRELOAD`:

```bash
LD_PRELOAD=$(clang -print-file-name=libasan.so) target/debug/bin
```
Hint: Cargo will crash if executed with `libasan` as preloaded library. Therefore, this is not ideal.

## Source Code

If you want to take a look at my experimental changes, you can visit my fork on [Github](https://github.com/maxammann/openssl-src-rs/blob/fuzz/src/lib.rs#L432).

## Failed Attempts

I'm not sure why the following attempt failed. But I'm quite certain that this is intended.

* Statically linking against `libclang_rt.asan-x86_64.a`. This can not work because we are instrumenting only a library and not the executable. The linker crashes with: `TLS transition from R_X86_64_TLSLD to R_X86_64_TPOFF32 against `_ZN6__asanL14fake_stack_tlsE' at 0x667 in section `.text' failed`.

## More References:

* [Questions on linking with -fsanitize=address](https://github.com/google/sanitizers/issues/1086)
* [How to enable address sanitizer for multiple C++ binaries](https://stackoverflow.com/questions/47021422/how-to-enable-address-sanitizer-for-multiple-c-binaries)
* [AddressSanitizer Flags](https://github.com/google/sanitizers/wiki/AddressSanitizerFlags)