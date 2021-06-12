---
layout: post
title: "Research Blog Introduction"
date: 2021-03-19
slug: fuzzing-1
draft: false

categories:
- research-blog
---

I will soon start my master thesis on the topic "Symbolic-Model-Guided Fuzzing of Cryptographic Protocols". I want to document my progress by doing a small blog series on Fuzzing related topics.

The initial papers which I read are:

* [Verified Models and Reference Implementations for the TLS 1.3 Standard Candidate](https://hal.inria.fr/hal-01575920v2)
* [Formal Models and Techniques for Analyzing Security Protocols: A Tutorial](https://ieeexplore.ieee.org/document/8187592)
* [The Art, Science, and Engineering of Fuzzing: A Survey](https://arxiv.org/abs/1812.00140)
* [A Messy State of the Union:Taming the Composite State Machines of TLS](https://www.ieee-security.org/TC/SP2015/papers-archived/6949a535.pdf])

I want to highlight some interesting aspects of these paper in the next blog post.

To get into the topic of fuzzing, I tried to implement a Fuzzer based on the upcoming and not yet officially released library "LibAFL" by AFLplusplus. I picked an easy target for the start. I tried to fuzz [libcue](https://github.com/lipnitsk/libcue). It worked, and I actually found the first bug in it withing seconds (a buffer underflow because of negative input). After that, I did not find quickly crashes. I suppose this is because libcue uses Yacc and a grammar to parse Cue files. Actually libcue is quite simple. Maybe too simple to have serious vulnerabilities like buffer overflows.

