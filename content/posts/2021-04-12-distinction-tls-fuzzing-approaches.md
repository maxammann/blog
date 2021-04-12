---
layout: post
title: "Distinction between Fuzzing Approaches for TLS"
date: 2021-04-12
slug: distinction-tls-fuzzing-approaches
draft: false

keywords: [ ]
categories: [ research-blog ]
---

This research blog focuses on novel ways to fuzz the TLS cryptographic protocol. Traditionally, fuzzing mutates bits and bytes. That means that the semantics of the protocol are not directly used to mutate the fuzzing input. [Symbolic-model Guided Fuzzing]({{< ref "2021-04-06-symbolic-model-guided" >}}) fuzzes on a more abstract level. It uses a symbolic model to create inputs. Therefore, there are two main approaches *bit-level fuzzing* and *model-guided fuzzing* (also called generation-based fuzzing) [^1]. This is also called [structure-aware fuzzing](https://github.com/google/fuzzing/blob/master/docs/structure-aware-fuzzing.md) by Google.

The classical example for a model which creates fuzz inputs is a grammar. A grammar of a programming language can directly generate syntactically correct programs encoded as text. Furthermore, such a grammar can generate abstract syntax trees (AST), which is just an encoding of the program which is easier to mutate. After mutating an abstract syntax tree it is possible to  serialize it to a text-file before passing it to the PUT. 

Note that an AST is similar indeed also a model. Therefore, one should differentiate between models which generate inputs (meta-model) and models which represent inputs.

## Bit-level Fuzzing

We will not dive into *bit-level fuzzing* as this evidence suggests that this technique is not able to create enough coverage paths which represent meaningful attack traces. <!-- TODO: Cite -->
This approach is not suitable for protocols, especially cryptographic ones. Later messages in a cryptographic protocol depend on random nonces generates in previous ones. That means it is very difficult to reach deep states. This is similar to overcome hash checks in traditional fuzzing. Note that checks against hashes are also used through-out TLS.


## Model-guided fuzzing

Now let's take a look at related approaches which use a model to fuzz TLS.

* [frankencerts](https://github.com/sumanj/frankencert)
  
  Generates "frankenstein" certificates for testing certificate validation
* [TLS-Attacker](https://github.com/tls-attacker/TLS-Attacker)

  Basically a TLS client which executes traces in configurable ways. Like: Send ClientHello with ECPointFormat and HeartbeatExtension. Expect ServerHello and Certificate messages from server. This allows to check for vulnerabilities like Heartbleed.
* [tlsfuzzer](https://tlsfuzzer.readthedocs.io/en/latest/testimonials.html)

  Allows one to create test-cases which send and expect TLS packets. `tlsfuzzer` can be run against a server to check for vulnerabilities like DROWN or ROBOT.
* ["Symbolic-Model-Aware Fuzzing of Cryptographic Protocols" by Guilhem Roy](https://members.loria.fr/LHirschi/#teaching)

  Uses [IJON](https://github.com/RUB-SysSec/ijon) to guide the fuzzer. The input for the PUT is a binary file which represents an abstract execution trace. This trace is mutated by standard AFL methods. The execution is guided by IJON, which uses a scoring. 

[frankencerts](https://github.com/sumanj/frankencert) focuses only on the certificates and therefore it not really interesting when fuzzing a protocol as a whole. It could serve as a building block though to increase coverage.

`tlsfuzzer` and `TLS-Attacker` are quite similar in the sense that they offer a programmatic way to specify and execute traces. They don't focus on fuzzing though. As they are implemented in Python and Java respectively it is also doubtful whether the code is usable in fuzzing, which usually requires a lot of runs to reach good edge or path coverage.


## Protobuf as binary format between Rust and OpenSSL

[^1]: [The Art, Science, and Engineering of Fuzzing: A Survey](https://arxiv.org/abs/1812.00140)