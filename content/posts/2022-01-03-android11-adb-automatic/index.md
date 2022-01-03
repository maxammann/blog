---
layout: post
title: "Stencil Testing using WebGPU wgpu"
date: 2021-12-15T13:30:22+01:00
slug: wgpu-stencil-testing
draft: true
wip: false

resources:
- src: "*.png"
- src: "*.jpg"

keywords: [ ]
categories: [ ]
---

Stencil testing refers to a technique in computer graphics programming which allows conditional processing of fragments. Stencil testing is closely related to depth testing which is used to determine which fragment precedence based on its depth within the scene.
In fact both tests are handled through the very same interface in WebGPU. The tests are handled through the [Depth/Stencil State](https://www.w3.org/TR/webgpu/#depth-stencil-state).

In this post we are focusing on a specific implementation of the WebGPU specification called [wgpu](https://github.com/gfx-rs/wgpu). It is a safe and portable GPU abstraction in Rust which implements the WebGPU API. Generally, the technique described below will also work for other implementations of WebGPU like it will be available in JavaScript.


In this post 
