---
title: "tlspuffin: TLS Protocol Under FuzzINg"
resources:
- src: 'logo.jpg'
  name: logo-light
technologies: [ OpenSSL, AFL, Rust ]
slug: tlspuffin
year: 2021
active: false
project_type: "Thesis"
github:
  - https://github.com/tlspuffin
external: []
---

A symbolic-model-guided fuzzer for TLS.

* Uses the [LibAFL fuzzing framework](https://github.com/AFLplusplus/LibAFL)
* Fuzzer which is inspired by the [Dolev-Yao symbolic model](https://en.wikipedia.org/wiki/Dolev%E2%80%93Yao_model) used in protocol verification
* Domain specific mutators for Protocol Fuzzing!
* Supported Libraries Under Test: OpenSSL 1.0.1f, 1.0.2u, 1.1.1k and LibreSSL 3.3.3
* Writtin in Rust!