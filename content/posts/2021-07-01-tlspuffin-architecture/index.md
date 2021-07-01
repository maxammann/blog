---
layout: post
title: "tlspuffin: Fuzzer Architecture"
date: 2021-07-01
slug: tlspuffin-heartbleed
draft: false

katex: false
hypothesis: true

keywords: []
categories: [research-blog]
---

We use [LibAFL](https://github.com/AFLplusplus/LibAFL) as a framework to implement the fuzzing loop. In the following we will discuss the design of tlspuffin and how we use LibAFL.


{{< resourceFigure "architecture.drawio.svg" >}}

{{< />}}