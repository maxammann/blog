---
layout: post
title: "tlspuffin: Method for Exploring the State Space"
date: 2021-06-03
slug: tlspuffin-method-explore
draft: true

katex: true
hypothesis: true

keywords: []
categories: [research-blog]
---

Motivation: openvpn formal verification -> still bugs found using fuzzing as there is a difference between a spec and impl

##

* Authentification Violations
  * Just expose a server public certificate
  * if we can trick Alice into thinking she is authentificated, then there is a vulnerability

##

Scope/Challenge: 
* How do we make sure we have enough function symbold?
* rusttls has some sanity checks
* rusttls does not implement every extension 
* fuzzing of openssl options

* PSK support.
* OCSP verification by clients.
* Certificate pinning.
* SSL1, SSL2, SSL3, TLS1 or TLS1.1.
* RC4.
* DES or triple DES.
* EXPORT ciphersuites.
* MAC-then-encrypt ciphersuites.
* Ciphersuites without forward secrecy.
* ~~Renegotiation.~~
* Kerberos.
* Compression.
* Discrete-log Diffie-Hellman.
* Automatic protocol version downgrade.
* AES-GCM with unsafe nonces.

Lucca interesting:
* TLS1.2 session resumption.
* TLS1.2 resumption via tickets (RFC5077).
* TLS1.3 resumption via tickets or session storage.