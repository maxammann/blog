---
layout: post
title: "tlspuffin: Method for Exploring the State Space"
date: 2021-06-03
slug: tlspuffin-method-explore
draft: false

katex: true
hypothesis: true

keywords: []
categories: [research-blog]
---

Motivation: openvpn formal verification -> still bugs found using fuzzing as there is a difference between a spec and impl

* Write sucessful seed without calling any openssl client code
  * implement client authentification and try to add a vulnerability to the server which accepts any 


* Authentification Violations
  * Just expose a server public certificate
  * if we can trick Alice into thinking she is authentificated, then there is a vulnerability


  Challenge: 
* How do we make sure we have enough function symbold?
* rusttls has some sanity checks
* rusttls does not implement every extension 
* fuzzing of openssl options