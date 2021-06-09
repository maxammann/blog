---
layout: post
title: "tlspuffin: Agree on a Protocol Specification"
date: 2021-06-09
slug: tlspuffin-protocol-specification
draft: true

katex: true
hypothesis: true

keywords: []
categories: [research-blog]
---


<!--

Mandatory extensions/cipher suits according to 1.3 RFC: https://www.davidwong.fr/tls13/#section-9

Creating fake extensions should be fine according to RFC: https://hypothes.is/a/drLnJMHfEeu2Z6dOVengvQ

https://github.com/ctz/rustls/blob/main/README.md

In Scope (rustls):

* TLS1.2 and TLS1.3.
* ECDSA, Ed25519 or RSA server authentication by clients.
* ECDSA, Ed25519 or RSA server authentication by servers.
* Forward secrecy using ECDHE; with curve25519, nistp256 or nistp384 curves.
* AES128-GCM and AES256-GCM bulk encryption, with safe nonces.
* ChaCha20-Poly1305 bulk encryption ([RFC7905](https://tools.ietf.org/html/rfc7905)).
* ALPN support.
* SNI support.
* Tunable fragment size to make TLS messages match size of underlying transport.
* Optional use of vectored IO to minimise system calls.
* TLS1.2 session resumption.
* TLS1.2 resumption via tickets ([RFC5077](https://tools.ietf.org/html/rfc5077)).
* TLS1.3 resumption via tickets or session storage.
* TLS1.3 0-RTT data for clients.
* Client authentication by clients.
* Client authentication by servers.
* Extended master secret support ([RFC7627](https://tools.ietf.org/html/rfc7627)).
* Exporters ([RFC5705](https://tools.ietf.org/html/rfc5705)).
* OCSP stapling by servers.
* SCT stapling by servers.
* SCT verification by clients.


Not in Scope (rustls):

* PSK support.
* OCSP verification by clients.
* Certificate pinning.

None Features (rustls):

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

Interesting:

* TLS1.2 session resumption.
* TLS1.2 resumption via tickets (RFC5077).
* TLS1.3 resumption via tickets or session storage.
* Fuzzing of OpenSSL Options
-->
