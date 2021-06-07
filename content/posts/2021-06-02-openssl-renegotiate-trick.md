---
layout: post
title: "OpenSSL: Inspect Secure Renegotiation"
date: 2021-06-07
slug: openssl-renegotiate
draft: false

keywords: [openssl]
categories: []
---

While trying to reproduce the implementation bug [CVE-2021-3449](https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2021-3449), I had to implement secure renegotiation as specified in [RFC 5746](https://datatracker.ietf.org/doc/html/rfc5746). Often it is unclear which RFC is responsible for specific protocol behavior. With the abundance of extensions, messages and protocol versions it is not trivial to find and also verify whether you found the correct specification.

Therefore, it can be helpful to use a tool like OpenSSL to experiment with Secure Renegotiation or Session Resumption in TLS 1.2 and check whether the found RFC is the correct one.

If you start an OpenSSL TLS client or server on the command line you have the possibility to pass the flat `-msg`. This will print the binary of the plaintext TLS messages. So you can even take a look at a usually encrypted renegotiation `ClientHello`, without intercepting network traffic with `tcpdump` or Wireshark.

The following two examples both start a client and a server which dump the internal TLS messages. To start a server we first need some dummy certificates which we can generate using the following command:

```bash
openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 365 -nodes
```
## Secure Renegotiation in TLS 1.2

Renegotiation is only available in TLS 1.2 and was removed from the 1.3 spec. Therefore, we start a TLS 1.2 server.

```bash
openssl s_server -key key.pem -cert cert.pem -accept 44330 -www -tls1_2 -msg
```

And start the client:

```bash
openssl s_client -msg -connect localhost:44330 -tls1_2
```

It is now possible to input a capital `R` and press `<Enter>`. By decoding it using Wireshark as described in a [previous post]({{< ref "2021-03-23-tls-overview" >}}), we can now inspect the extensions like `renegotiation_info`.


```kotlin
TLSv1.2 Record Layer: Handshake Protocol: Client Hello
    Content Type: Handshake (22)
    Version: TLS 1.2 (0x0303)
    Length: 204
    Handshake Protocol: Client Hello
        Handshake Type: Client Hello (1)
        Length: 200
        Version: TLS 1.2 (0x0303)
        Random: 05c2bf8abe4aa85d3b9d3127e1c805289c3a71556f93bd269adff1b5d82f04bc
            GMT Unix Time: Jan 23, 1973 15:58:18.000000000 CET
            Random Bytes: be4aa85d3b9d3127e1c805289c3a71556f93bd269adff1b5d82f04bc
        Session ID Length: 0
        Cipher Suites Length: 54
        Cipher Suites (27 suites)
            Cipher Suite: TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384 (0xc02c)
            ...
        Compression Methods Length: 1
        Compression Methods (1 method)
            Compression Method: null (0)
        Extensions Length: 105
        Extension: renegotiation_info (len=13)
            Type: renegotiation_info (65281)
            Length: 13
            Renegotiation Info extension
                Renegotiation info extension length: 12
                Renegotiation info: b5a38b5e23f4bca242b07119
        Extension: ec_point_formats (len=4)
            Type: ec_point_formats (11)
            Length: 4
            EC point formats Length: 3
            Elliptic curves point formats (3)
                EC point format: uncompressed (0)
                EC point format: ansiX962_compressed_prime (1)
                EC point format: ansiX962_compressed_char2 (2)
        Extension: supported_groups (len=12)
            Type: supported_groups (10)
            Length: 12
            Supported Groups List Length: 10
            Supported Groups (5 groups)
                Supported Group: x25519 (0x001d)
                Supported Group: secp256r1 (0x0017)
                Supported Group: x448 (0x001e)
                Supported Group: secp521r1 (0x0019)
                Supported Group: secp384r1 (0x0018)
        Extension: session_ticket (len=0)
            Type: session_ticket (35)
            Length: 0
            Data (0 bytes)
        Extension: encrypt_then_mac (len=0)
            Type: encrypt_then_mac (22)
            Length: 0
        Extension: extended_master_secret (len=0)
            Type: extended_master_secret (23)
            Length: 0
        Extension: signature_algorithms (len=48)
            Type: signature_algorithms (13)
            Length: 48
            Signature Hash Algorithms Length: 46
            Signature Hash Algorithms (23 algorithms)
                Signature Algorithm: ecdsa_secp256r1_sha256 (0x0403)
                    Signature Hash Algorithm Hash: SHA256 (4)
                    Signature Hash Algorithm Signature: ECDSA (3)
                ...
```


## Session Resumption in TLS 1.2

Similarly, we can trigger a session resumption by passing the `-reconnect` flag to the OpenSSL client.

```bash
openssl s_client -msg -connect localhost:44330 -tls1_2 --reconnect
```

OpenSSL will do a full handshake, then close the connection and reconnect using an abbreviated handshake.