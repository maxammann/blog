---
layout: post
title: "Dissecting TLS using OpenSSL and Wireshark"
date: 2021-03-23
slug: tls-overview
draft: false

katex: true

resources:
- openssl_messages.*

keywords: [ ]
categories: [ research-blog ]
---

TLS is a beast of a protocol with at least [50 extensions](https://www.iana.org/assignments/tls-extensiontype-values/tls-extensiontype-values.xhtml) and over 20 years of history. This indicates that implementing can be challenging and that it is important to take a close look at its security.
TLS drives the web of today. The web can not exist without it anymore. Not only that secrecy and authentication is a must-have today, it is also required by specifications like [getUserMedia](https://developer.mozilla.org/en-US/docs/Web/API/MediaDevices/getUserMedia) for WebRTC streaming.

## The State Machine

Implementations of TLS usually expose an API which allows to parse and generate messages. Each time a new message is received the TLS library is responsible to update the client or server state and send out the next message [^1]. Cryptographic operations are executed below the API layer. 

Messages can be intercepted or tampered with while they travel from one endpoint to the other. Also new messages can be injected. The task of TLS is to make sure that specific security properties of the connection like Secrecy, Forward Secrecy or Authentication are enforced.

The state machine of TLS is not formally specified [^1]. Therefore, each TLS library has some freedom in handling the state transitions and edge cases.

## Steps in the TLS Handshake

\@XargsNotBombs has illustrated the TLS handshake beautifully [here](https://tls13.ulfheim.net/). I will describe it here in a more texty way.

I am also doing here something similar like the above illustration. My approach is just more manual and simpler. I will create here a connection to the HTTP server of this blog and send some data: `openssl s_client -msg -connect maxammann.org:443`. This command logs all messages of the handshake as hex.

This approach has the advantage that it requirest just OpenSSL and some tool to interpret binary messages like WireShark. It does not require any complex setup to look inside of encrypted TLS messages.

💻 denotes a client and ☁️ a server which could be hosted in the cloud.

### 💻 ➔ ☁️ ClientHello

We will start by generating a client private $sk_C$ and public $pk_C$ key for which will be used in the elliptic curve Diffie-Hellman key exchange (ECDH). 

In TLS 1.3 "static RSA and Diffie-Hellman cipher suites have been removed" [^2]. Key exchanges are only done using DHE. That means the names of cipher suites also are simpler now. You can query cipher suits of OpenSSL using these commands for TLS 1.2 and 1.3:

```bash
openssl ciphers -v -s -tls1_2
openssl ciphers -v -s -tls1_3
```

In my case the output for TLS 1.3 is significantly smaller. You also notice that the key exchange algorithm is no longer specified in the name of the cipher suite. The key exchange algorithm is determined in Client and Server Hello. For example the cipher suite [TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384](https://ciphersuite.info/cs/TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384/) states that the key exchange should happen through Elliptic Curve Diffie-Hellman Ephemeral. The site ciphersuite.info is actually quite cool as it documents all the available cipher suits out there.

Now back to the key generation. We can generate the private key using OpenSSL.

```bash
openssl genpkey -algorithm x25519 -out -
-----BEGIN PRIVATE KEY-----
MC4CAQAwBQYDK2VuBCIEIAhAXnd7oaF01rCz5dUfnh8oVSONL4J0kh4I10OwljlH
-----END PRIVATE KEY-----
``` 

For the public key:

```bash
$ openssl pkey -in - -pubout -out -
-----BEGIN PUBLIC KEY-----
MCowBQYDK2VuAyEAr84Q+eKbCCSFmvV89tgxd6lRL57rpQYCX4C7eNlb1Wc=
-----END PUBLIC KEY-----
```

Now we are sending the ClientHello, which starts with a [Record Header](https://tools.ietf.org/html/rfc8446#section-5.1):

```hexdump
16 03 01 01 36
```

* Type is `0x16`
* Protocol Version is 3,1 (TLS 1.0) for interoperability reasons
* Handshake Length is `0x0137`

The ClientHello includes 0x0136 bytes of Handshake data:

```hexdump
00000000  16 03 01 01 36 01 00 01 32 03 03 aa 17 95 f6 4f  |....6...2......O|
00000010  48 fc fc d0 12 13 68 f8 8f 17 6f e2 57 0b 07 68  |H.....h...o.W..h|
00000020  bb c8 5e 9f 2c 80 c5 57 55 3d 7d 20 e1 e1 5d 00  |..^.,..WU=} ..].|
00000030  28 93 2f 4f 74 79 cf 25 63 02 b7 84 7d 81 a6 8e  |(./Oty.%c...}...|
00000040  70 85 25 f9 d3 8d 94 fc 6e f7 42 a3 00 3e 13 02  |p.%.....n.B..>..|
00000050  13 03 13 01 c0 2c c0 30 00 9f cc a9 cc a8 cc aa  |.....,.0........|
00000060  c0 2b c0 2f 00 9e c0 24 c0 28 00 6b c0 23 c0 27  |.+./...$.(.k.#.'|
00000070  00 67 c0 0a c0 14 00 39 c0 09 c0 13 00 33 00 9d  |.g.....9.....3..|
00000080  00 9c 00 3d 00 3c 00 35 00 2f 00 ff 01 00 00 ab  |...=.<.5./......|
00000090  00 00 00 12 00 10 00 00 0d 6d 61 78 61 6d 6d 61  |.........maxamma|
000000a0  6e 6e 2e 6f 72 67 00 0b 00 04 03 00 01 02 00 0a  |nn.org..........|
000000b0  00 0c 00 0a 00 1d 00 17 00 1e 00 19 00 18 00 23  |...............#|
000000c0  00 00 00 16 00 00 00 17 00 00 00 0d 00 30 00 2e  |.............0..|
000000d0  04 03 05 03 06 03 08 07 08 08 08 09 08 0a 08 0b  |................|
000000e0  08 04 08 05 08 06 04 01 05 01 06 01 03 03 02 03  |................|
000000f0  03 01 02 01 03 02 02 02 04 02 05 02 06 02 00 2b  |...............+|
00000100  00 09 08 03 04 03 03 03 02 03 01 00 2d 00 02 01  |............-...|
00000110  01 00 33 00 26 00 24 00 1d 00 20 9b 8a 24 e2 97  |..3.&.$... ..$..|
00000120  70 f7 ed 95 bf 33 0e 7e 39 29 b2 10 90 35 0a 41  |p....3.~9)...5.A|
00000130  5a b4 cd f0 1b 04 e9 ff c0 fc 50                 |Z.........P|
```

Now we can simply import this data into Wireshark to analyze it in a simple way. I fist used CyberChef to create a properly formatted hex dump from the values and then loaded them in Wirehark. The plain OpenSSL output can be seen in {{< resourceHref openssl_messages.txt >}}openssl_messages.txt{{< /resourceHref >}}. From this file I {{< resourceHref openssl_messages.hex >}}cleaned it up{{< /resourceHref >}} by adding missing TLS record headers like `16 03 01 01 36` where the last 2 bytes specify the length of the next message. These were crafted manually in order to make it possible to parse them with wireshark. Finally, I removed the comments and put it into [CyberChef](https://gchq.github.io/CyberChef/#recipe=From_Hex('Auto')To_Hexdump(16,false,false,false)) to create a {{< resourceHref openssl_messages.hexdump >}}hexdump{{< /resourceHref >}}.

You have to tell Wireshark to generate a dummy TCP header around it, else the detection fails. The final pcap file can be downloaded {{< resourceHref openssl_messages.pcap >}}here{{< /resourceHref >}}.
You can now expor this as JSON or use a pretty printed version (Right-click on TLS packet and "Copy > All Visible Items")

{{< collapsible "Client Hello Header" >}}
```yaml
TLSv1.3 Record Layer: Handshake Protocol: Client Hello
    Content Type: Handshake (22)
    Version: TLS 1.0 (0x0301)
    Length: 310
    Handshake Protocol: Client Hello
        Handshake Type: Client Hello (1)
        Length: 306
        # Version represents TLS 1.2 for interoparability reasons
        Version: TLS 1.2 (0x0303)
        # Random value for later use
        Random: aa1795f64f48fcfcd0121368f88f176fe2570b0768bbc85e9f2c80c557553d7d
        # Random data as TLS 1.3 uses the PSK method for session resuming
        Session ID Length: 32
        Session ID: e1e15d0028932f4f7479cf256302b7847d81a68e708525f9d38d94fc6ef742a3
```
{{< /collapsible >}}
{{< collapsible "Advertise Ciphers and Compression" >}}
```yaml     
        # Available cipher suits 
        Cipher Suites Length: 62
        Cipher Suites (31 suites)
            Cipher Suite: TLS_AES_256_GCM_SHA384 (0x1302)
            Cipher Suite: TLS_CHACHA20_POLY1305_SHA256 (0x1303)
            Cipher Suite: TLS_AES_128_GCM_SHA256 (0x1301)
            Cipher Suite: TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384 (0xc02c)
            Cipher Suite: TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384 (0xc030)
            Cipher Suite: TLS_DHE_RSA_WITH_AES_256_GCM_SHA384 (0x009f)
            Cipher Suite: TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256 (0xcca9)
            Cipher Suite: TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256 (0xcca8)
            Cipher Suite: TLS_DHE_RSA_WITH_CHACHA20_POLY1305_SHA256 (0xccaa)
            Cipher Suite: TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256 (0xc02b)
            Cipher Suite: TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256 (0xc02f)
            Cipher Suite: TLS_DHE_RSA_WITH_AES_128_GCM_SHA256 (0x009e)
            Cipher Suite: TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384 (0xc024)
            Cipher Suite: TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384 (0xc028)
            Cipher Suite: TLS_DHE_RSA_WITH_AES_256_CBC_SHA256 (0x006b)
            Cipher Suite: TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256 (0xc023)
            Cipher Suite: TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256 (0xc027)
            Cipher Suite: TLS_DHE_RSA_WITH_AES_128_CBC_SHA256 (0x0067)
            Cipher Suite: TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA (0xc00a)
            Cipher Suite: TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA (0xc014)
            Cipher Suite: TLS_DHE_RSA_WITH_AES_256_CBC_SHA (0x0039)
            Cipher Suite: TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA (0xc009)
            Cipher Suite: TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA (0xc013)
            Cipher Suite: TLS_DHE_RSA_WITH_AES_128_CBC_SHA (0x0033)
            Cipher Suite: TLS_RSA_WITH_AES_256_GCM_SHA384 (0x009d)
            Cipher Suite: TLS_RSA_WITH_AES_128_GCM_SHA256 (0x009c)
            Cipher Suite: TLS_RSA_WITH_AES_256_CBC_SHA256 (0x003d)
            Cipher Suite: TLS_RSA_WITH_AES_128_CBC_SHA256 (0x003c)
            Cipher Suite: TLS_RSA_WITH_AES_256_CBC_SHA (0x0035)
            Cipher Suite: TLS_RSA_WITH_AES_128_CBC_SHA (0x002f)
            Cipher Suite: TLS_EMPTY_RENEGOTIATION_INFO_SCSV (0x00ff)
        # Compression, in TLS 1.3 compression is not allowed because of CRIME attack 
        Compression Methods Length: 1
        Compression Methods (1 method)
            Compression Method: null (0)
```
{{< /collapsible >}}
{{< collapsible Extensions >}}
```yaml    
        Extensions Length: 171
        # Used when using multiple virtual servers in NGINX/Apache for example
        Extension: server_name (len=18)
            Type: server_name (0)
            Length: 18
            Server Name Indication extension
                Server Name list length: 16
                Server Name Type: host_name (0)
                Server Name length: 13
                Server Name: maxammann.org
        # Supported curves for EC cryptography
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
        # Supported signature algorithms of the client, determines the certificate sent by server
        Extension: signature_algorithms (len=48)
            Type: signature_algorithms (13)
            Length: 48
            Signature Hash Algorithms Length: 46
            Signature Hash Algorithms (23 algorithms)
                Signature Algorithm: ecdsa_secp256r1_sha256 (0x0403)
                    Signature Hash Algorithm Hash: SHA256 (4)
                    Signature Hash Algorithm Signature: ECDSA (3)
                Signature Algorithm: ecdsa_secp384r1_sha384 (0x0503)
                    Signature Hash Algorithm Hash: SHA384 (5)
                    Signature Hash Algorithm Signature: ECDSA (3)
                Signature Algorithm: ecdsa_secp521r1_sha512 (0x0603)
                    Signature Hash Algorithm Hash: SHA512 (6)
                    Signature Hash Algorithm Signature: ECDSA (3)
                Signature Algorithm: ed25519 (0x0807)
                    Signature Hash Algorithm Hash: Unknown (8)
                    Signature Hash Algorithm Signature: Unknown (7)
                Signature Algorithm: ed448 (0x0808)
                    Signature Hash Algorithm Hash: Unknown (8)
                    Signature Hash Algorithm Signature: Unknown (8)
                Signature Algorithm: rsa_pss_pss_sha256 (0x0809)
                    Signature Hash Algorithm Hash: Unknown (8)
                    Signature Hash Algorithm Signature: Unknown (9)
                Signature Algorithm: rsa_pss_pss_sha384 (0x080a)
                    Signature Hash Algorithm Hash: Unknown (8)
                    Signature Hash Algorithm Signature: Unknown (10)
                Signature Algorithm: rsa_pss_pss_sha512 (0x080b)
                    Signature Hash Algorithm Hash: Unknown (8)
                    Signature Hash Algorithm Signature: Unknown (11)
                Signature Algorithm: rsa_pss_rsae_sha256 (0x0804)
                    Signature Hash Algorithm Hash: Unknown (8)
                    Signature Hash Algorithm Signature: Unknown (4)
                Signature Algorithm: rsa_pss_rsae_sha384 (0x0805)
                    Signature Hash Algorithm Hash: Unknown (8)
                    Signature Hash Algorithm Signature: Unknown (5)
                Signature Algorithm: rsa_pss_rsae_sha512 (0x0806)
                    Signature Hash Algorithm Hash: Unknown (8)
                    Signature Hash Algorithm Signature: Unknown (6)
                Signature Algorithm: rsa_pkcs1_sha256 (0x0401)
                    Signature Hash Algorithm Hash: SHA256 (4)
                    Signature Hash Algorithm Signature: RSA (1)
                Signature Algorithm: rsa_pkcs1_sha384 (0x0501)
                    Signature Hash Algorithm Hash: SHA384 (5)
                    Signature Hash Algorithm Signature: RSA (1)
                Signature Algorithm: rsa_pkcs1_sha512 (0x0601)
                    Signature Hash Algorithm Hash: SHA512 (6)
                    Signature Hash Algorithm Signature: RSA (1)
                Signature Algorithm: SHA224 ECDSA (0x0303)
                    Signature Hash Algorithm Hash: SHA224 (3)
                    Signature Hash Algorithm Signature: ECDSA (3)
                Signature Algorithm: ecdsa_sha1 (0x0203)
                    Signature Hash Algorithm Hash: SHA1 (2)
                    Signature Hash Algorithm Signature: ECDSA (3)
                Signature Algorithm: SHA224 RSA (0x0301)
                    Signature Hash Algorithm Hash: SHA224 (3)
                    Signature Hash Algorithm Signature: RSA (1)
                Signature Algorithm: rsa_pkcs1_sha1 (0x0201)
                    Signature Hash Algorithm Hash: SHA1 (2)
                    Signature Hash Algorithm Signature: RSA (1)
                Signature Algorithm: SHA224 DSA (0x0302)
                    Signature Hash Algorithm Hash: SHA224 (3)
                    Signature Hash Algorithm Signature: DSA (2)
                Signature Algorithm: SHA1 DSA (0x0202)
                    Signature Hash Algorithm Hash: SHA1 (2)
                    Signature Hash Algorithm Signature: DSA (2)
                Signature Algorithm: SHA256 DSA (0x0402)
                    Signature Hash Algorithm Hash: SHA256 (4)
                    Signature Hash Algorithm Signature: DSA (2)
                Signature Algorithm: SHA384 DSA (0x0502)
                    Signature Hash Algorithm Hash: SHA384 (5)
                    Signature Hash Algorithm Signature: DSA (2)
                Signature Algorithm: SHA512 DSA (0x0602)
                    Signature Hash Algorithm Hash: SHA512 (6)
                    Signature Hash Algorithm Signature: DSA (2)
        # Specify suppor of the client for example for TLS 1.0 - 1.3
        Extension: supported_versions (len=9)
            Type: supported_versions (43)
            Length: 9
            Supported Versions length: 8
            Supported Version: TLS 1.3 (0x0304)
            Supported Version: TLS 1.2 (0x0303)
            Supported Version: TLS 1.1 (0x0302)
            Supported Version: TLS 1.0 (0x0301)
        # Specifies the available modes for use of PSK (for example for 0-RTT)
        Extension: psk_key_exchange_modes (len=2)
            Type: psk_key_exchange_modes (45)
            Length: 2
            PSK Key Exchange Modes Length: 1
            PSK Key Exchange Mode: PSK with (EC)DHE key establishment (psk_dhe_ke) (1)
        # Public key sent by the client for encrypting the following messages (see above how pk_C and sk_C are created)
        Extension: key_share (len=38)
            Type: key_share (51)
            Length: 38
            Key Share extension
                Client Key Share Length: 36
                Key Share Entry: Group: x25519, Key Exchange length: 32
                    Group: x25519 (29)
                    Key Exchange Length: 32
                    Key Exchange: 9b8a24e29770f7ed95bf330e7e3929b21090350a415ab4cdf01b04e9ffc0fc50
```
{{< /collapsible >}}
<!---
TODO, see what these extensions do
-->
{{< collapsible "Other Extensions" >}}
```yaml
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
        Extension: ec_point_formats (len=4)
            Type: ec_point_formats (11)
            Length: 4
            EC point formats Length: 3
            Elliptic curves point formats (3)
                EC point format: uncompressed (0)
                EC point format: ansiX962_compressed_prime (1)
                EC point format: ansiX962_compressed_char2 (2)
```
{{< /collapsible >}}

### ☁️ ➔ 💻 Server Hello

The server will also generate a public and private key for DH key exchange. This is done in the same way as in Client Hello (`openssl genpkey -algorithm x25519`). So now we have the keys $sk_S$ and public $pk_S$.

{{< collapsible "Disassembly" >}}
```yaml
TLSv1.3 Record Layer: Handshake Protocol: Server Hello
    Content Type: Handshake (22)
    Version: TLS 1.2 (0x0303)
    Length: 122
    Handshake Protocol: Server Hello
        Handshake Type: Server Hello (2)
        Length: 118
        # Same as in Client Hello: We need to disguise as TLS 1.2
        Version: TLS 1.2 (0x0303)
        # Random value which will be used later on (TODO: Where?!)
        Random: debc41503f1f52ec094f9bdf2c0f941db8928069d202f352201b337bea4ed436
        Session ID Length: 32
        # Session ID of the client, this is no longer sued in TLS 1.3
        Session ID: e1e15d0028932f4f7479cf256302b7847d81a68e708525f9d38d94fc6ef742a3
        # The selected cipher suite
        Cipher Suite: TLS_AES_256_GCM_SHA384 (0x1302)
        # Compression method selected by client
        Compression Method: null (0)
        Extensions Length: 46
        # Specifies that we are using TLS 1.3
        Extension: supported_versions (len=2)
            Type: supported_versions (43)
            Length: 2
            Supported Version: TLS 1.3 (0x0304)
        # Contains the public key of the server which is used in DH (see above how pk_S and sk_S are created)
        Extension: key_share (len=36)
            Type: key_share (51)
            Length: 36
            Key Share extension
                Key Share Entry: Group: x25519, Key Exchange length: 32
                    Group: x25519 (29)
                    Key Exchange Length: 32
                    Key Exchange: 8cbdb10a727ffe655f368521b39a16146d55ff144a0f95235ccd1925c31f6137
```
{{< /collapsible >}}

Now we are ready to calculate the keys which are used in the encryption of the following handshake messages. The server calculates $sk_S \* pk_C$. Now we calculate the SHA256 hash of all sent bytes so far, except the record headers. This includes Client and Server Hello so far. This is also called the transcript hash.

The transcript hash and secret are now fed to a KDF procedure. From this data we derive multiple secrets using `HKDF-Extract` and `HKDF-Expand-Label` specified in [RFC-5869](https://tools.ietf.org/html/rfc5869).

We have now ([RFC8446 7.1](https://tools.ietf.org/html/rfc8446#section-7.1))

* client\_handshake\_traffic\_secret
* server\_handshake\_traffic\_secret.

From these secrets we can derive keys and IVs: ([RFC8446 7.3](https://tools.ietf.org/html/rfc8446#section-7.3)):

* client\_handshake\_key & client\_handshake\_iv
* server\_handshake\_key & server\_handshake\_iv.

The cool thing is that because of the Diffie Hellman key exchange the client can calculate the same values as it has the transcript hash, client private key and the server public key. That means client\_handshake\_traffic\_secret = server\_handshake\_traffic\_secret and the same for the IV.

### ☁️ ➔ 💻 Change Cipher Spec

This record is sent to disguise as TLS 1.2.

{{< collapsible "Disassembly" >}}
```yaml
TLSv1.3 Record Layer: Change Cipher Spec Protocol: Change Cipher Spec
    Content Type: Change Cipher Spec (20)
    Version: TLS 1.2 (0x0303)
    Length: 1
    Change Cipher Spec Message
```
{{< /collapsible >}}

### ☁️ ➔ 💻 Encrypted Extensions (Encrypted 🔐)

This is the first message which is encrypted using the server handshake keys and IVs like described in Server Hello. An AEAD authentification tag possibly is included to achive integrity.

This handshake record contains more extensions which are transmitted encrypted.

{{< collapsible "Other Extensions" >}}
```yaml
TLSv1.3 Record Layer: Handshake Protocol: Encrypted Extensions
    Content Type: Handshake (22)
    Version: TLS 1.2 (0x0303)
    Length: 10
    Handshake Protocol: Encrypted Extensions
        Handshake Type: Encrypted Extensions (8)
        Length: 6
        Extensions Length: 4
        Extension: server_name (len=0)
            Type: server_name (0)
            Length: 0
```
{{< /collapsible >}}

### ☁️ ➔ 💻 Certificate (🔐)

This message contains the certificate chain. Certificates are encoded in DER. Wireshark makes it easy to look into the certificates. Certificate chains are basically just a list of certificates. If you want to play with certificates then you can use the OpenSSL CLI. The command `openssl verify -verbose -CAfile ca.pem chain.pem` verifies a chain. `ca.pem` would be a root certificate which you trust. `chain.pem` contains all the files in an ASCII format separated by new lines. OpenSSl reports then whether it is fine or not. When using the `openssl s_client -connect` command you also see the certificates and verbose output about the validation.

{{< collapsible "Certificate Hello" >}}
```yaml
TLSv1.3 Record Layer: Handshake Protocol: Certificate
    Content Type: Handshake (22)
    Version: TLS 1.2 (0x0303)
    Length: 2485
    Handshake Protocol: Certificate
        Handshake Type: Certificate (11)
        Length: 2481
        Certificate Request Context Length: 0
        Certificates Length: 2477
        Certificates (2477 bytes)
```
{{< /collapsible >}}


{{< collapsible "Let's Encrypt Certificate for maxammann.org" >}}
```yaml
            Certificate Length: 1338
            Certificate: 308205363082041ea00302010202120400ca5961d39c1622093596f2132488f93e300d06… (id-at-commonName=www.maxammann.org)
                signedCertificate
                    version: v3 (2)
                    serialNumber: 0x0400ca5961d39c1622093596f2132488f93e
                    signature (sha256WithRSAEncryption)
                        Algorithm Id: 1.2.840.113549.1.1.11 (sha256WithRSAEncryption)
                    issuer: rdnSequence (0)
                        rdnSequence: 3 items (id-at-commonName=R3,id-at-organizationName=Let's Encrypt,id-at-countryName=US)
                            RDNSequence item: 1 item (id-at-countryName=US)
                                RelativeDistinguishedName item (id-at-countryName=US)
                                    Id: 2.5.4.6 (id-at-countryName)
                                    CountryName: US
                            RDNSequence item: 1 item (id-at-organizationName=Let's Encrypt)
                                RelativeDistinguishedName item (id-at-organizationName=Let's Encrypt)
                                    Id: 2.5.4.10 (id-at-organizationName)
                                    DirectoryString: printableString (1)
                                        printableString: Let's Encrypt
                            RDNSequence item: 1 item (id-at-commonName=R3)
                                RelativeDistinguishedName item (id-at-commonName=R3)
                                    Id: 2.5.4.3 (id-at-commonName)
                                    DirectoryString: printableString (1)
                                        printableString: R3
                    validity
                        notBefore: utcTime (0)
                            utcTime: 2021-03-28 01:43:58 (UTC)
                        notAfter: utcTime (0)
                            utcTime: 2021-06-26 01:43:58 (UTC)
                    subject: rdnSequence (0)
                        rdnSequence: 1 item (id-at-commonName=www.maxammann.org)
                            RDNSequence item: 1 item (id-at-commonName=www.maxammann.org)
                                RelativeDistinguishedName item (id-at-commonName=www.maxammann.org)
                                    Id: 2.5.4.3 (id-at-commonName)
                                    DirectoryString: printableString (1)
                                        printableString: www.maxammann.org
                    subjectPublicKeyInfo
                        algorithm (rsaEncryption)
                            Algorithm Id: 1.2.840.113549.1.1.1 (rsaEncryption)
                        subjectPublicKey: 3082010a0282010100b8ad1a3825f4aa8f8cdf5221a5d98d29f93be72f470397e07e1cec…
                            modulus: 0x00b8ad1a3825f4aa8f8cdf5221a5d98d29f93be72f470397e07e1ceca379376bf1b148d1…
                            publicExponent: 65537
                    extensions: 9 items
                        Extension (id-ce-keyUsage)
                            Extension Id: 2.5.29.15 (id-ce-keyUsage)
                            critical: True
                            Padding: 5
                            KeyUsage: a0
                                1... .... = digitalSignature: True
                                .0.. .... = contentCommitment: False
                                ..1. .... = keyEncipherment: True
                                ...0 .... = dataEncipherment: False
                                .... 0... = keyAgreement: False
                                .... .0.. = keyCertSign: False
                                .... ..0. = cRLSign: False
                                .... ...0 = encipherOnly: False
                                0... .... = decipherOnly: False
                        Extension (id-ce-extKeyUsage)
                            Extension Id: 2.5.29.37 (id-ce-extKeyUsage)
                            KeyPurposeIDs: 2 items
                                KeyPurposeId: 1.3.6.1.5.5.7.3.1 (id-kp-serverAuth)
                                KeyPurposeId: 1.3.6.1.5.5.7.3.2 (id-kp-clientAuth)
                        Extension (id-ce-basicConstraints)
                            Extension Id: 2.5.29.19 (id-ce-basicConstraints)
                            critical: True
                            BasicConstraintsSyntax [0 length]
                        Extension (id-ce-subjectKeyIdentifier)
                            Extension Id: 2.5.29.14 (id-ce-subjectKeyIdentifier)
                            SubjectKeyIdentifier: 12b43a1e54091741afc831d1e4de7babcb110ebe
                        Extension (id-ce-authorityKeyIdentifier)
                            Extension Id: 2.5.29.35 (id-ce-authorityKeyIdentifier)
                            AuthorityKeyIdentifier
                                keyIdentifier: 142eb317b75856cbae500940e61faf9d8b14c2c6
                        Extension (id-pe-authorityInfoAccess)
                            Extension Id: 1.3.6.1.5.5.7.1.1 (id-pe-authorityInfoAccess)
                            AuthorityInfoAccessSyntax: 2 items
                                AccessDescription
                                    accessMethod: 1.3.6.1.5.5.7.48.1 (id-ad-ocsp)
                                    accessLocation: 6
                                        uniformResourceIdentifier: http://r3.o.lencr.org
                                AccessDescription
                                    accessMethod: 1.3.6.1.5.5.7.48.2 (id-ad-caIssuers)
                                    accessLocation: 6
                                        uniformResourceIdentifier: http://r3.i.lencr.org/
                        Extension (id-ce-subjectAltName)
                            Extension Id: 2.5.29.17 (id-ce-subjectAltName)
                            GeneralNames: 2 items
                                GeneralName: dNSName (2)
                                    dNSName: maxammann.org
                                GeneralName: dNSName (2)
                                    dNSName: www.maxammann.org
                        Extension (id-ce-certificatePolicies)
                            Extension Id: 2.5.29.32 (id-ce-certificatePolicies)
                            CertificatePoliciesSyntax: 2 items
                                PolicyInformation
                                    policyIdentifier: 2.23.140.1.2.1 (joint-iso-itu-t.23.140.1.2.1)
                                PolicyInformation
                                    policyIdentifier: 1.3.6.1.4.1.44947.1.1.1 (iso.3.6.1.4.1.44947.1.1.1)
                                    policyQualifiers: 1 item
                                        PolicyQualifierInfo
                                            Id: 1.3.6.1.5.5.7.2.1 (id-qt-cps)
                                            DirectoryString: http://cps.letsencrypt.org
                        Extension (SignedCertificateTimestampList)
                            Extension Id: 1.3.6.1.4.1.11129.2.4.2 (SignedCertificateTimestampList)
                            Serialized SCT List Length: 239
                            Signed Certificate Timestamp (Cloudflare 'Nimbus2021' Log)
                                Serialized SCT Length: 118
                                SCT Version: 0
                                Log ID: 4494652eb0eeceafc44007d8a8fe28c0dae682bed8cb31b53fd33396b5b681a8
                                Timestamp: Mar 28, 2021 02:43:58.350000000 UTC
                                Extensions length: 0
                                Signature Algorithm: ecdsa_secp256r1_sha256 (0x0403)
                                    Signature Hash Algorithm Hash: SHA256 (4)
                                    Signature Hash Algorithm Signature: ECDSA (3)
                                Signature Length: 71
                                Signature: 304502201c5b58adfa5df8abf6077d94b765750a24d32b49b3af2dcf5c65efaf32c949d6…
                            Signed Certificate Timestamp (Google 'Xenon2021' log)
                                Serialized SCT Length: 117
                                SCT Version: 0
                                Log ID: 7d3ef2f88fff88556824c2c0ca9e5289792bc50e78097f2e6a9768997e22f0d7
                                Timestamp: Mar 28, 2021 02:43:58.382000000 UTC
                                Extensions length: 0
                                Signature Algorithm: ecdsa_secp256r1_sha256 (0x0403)
                                    Signature Hash Algorithm Hash: SHA256 (4)
                                    Signature Hash Algorithm Signature: ECDSA (3)
                                Signature Length: 70
                                Signature: 30440220030a54d2296566cab9b5fa3e6505566e5e014d48f15f6cd8727896e2cc352eb3…
                algorithmIdentifier (sha256WithRSAEncryption)
                    Algorithm Id: 1.2.840.113549.1.1.11 (sha256WithRSAEncryption)
                Padding: 0
                encrypted: 8c770bcf525fc99d9f8f04d279b724bbb2bebc42184e671aa392b058265b097de2d9f668…
            Extensions Length: 0
```
{{< /collapsible >}}


{{< collapsible "DST Root CA X3 Certificate for Let's Encrypt" >}}
```yaml
            Certificate Length: 1129
            Certificate: 308204653082034da0030201020210400175048314a4c8218c84a90c16cddf300d06092a… (id-at-commonName=R3,id-at-organizationName=Let's Encrypt,id-at-countryName=US)
                signedCertificate
                    version: v3 (2)
                    serialNumber: 0x400175048314a4c8218c84a90c16cddf
                    signature (sha256WithRSAEncryption)
                        Algorithm Id: 1.2.840.113549.1.1.11 (sha256WithRSAEncryption)
                    issuer: rdnSequence (0)
                        rdnSequence: 2 items (id-at-commonName=DST Root CA X3,id-at-organizationName=Digital Signature Trust Co.)
                            RDNSequence item: 1 item (id-at-organizationName=Digital Signature Trust Co.)
                                RelativeDistinguishedName item (id-at-organizationName=Digital Signature Trust Co.)
                                    Id: 2.5.4.10 (id-at-organizationName)
                                    DirectoryString: printableString (1)
                                        printableString: Digital Signature Trust Co.
                            RDNSequence item: 1 item (id-at-commonName=DST Root CA X3)
                                RelativeDistinguishedName item (id-at-commonName=DST Root CA X3)
                                    Id: 2.5.4.3 (id-at-commonName)
                                    DirectoryString: printableString (1)
                                        printableString: DST Root CA X3
                    validity
                        notBefore: utcTime (0)
                            utcTime: 2020-10-07 19:21:40 (UTC)
                        notAfter: utcTime (0)
                            utcTime: 2021-09-29 19:21:40 (UTC)
                    subject: rdnSequence (0)
                        rdnSequence: 3 items (id-at-commonName=R3,id-at-organizationName=Let's Encrypt,id-at-countryName=US)
                            RDNSequence item: 1 item (id-at-countryName=US)
                                RelativeDistinguishedName item (id-at-countryName=US)
                                    Id: 2.5.4.6 (id-at-countryName)
                                    CountryName: US
                            RDNSequence item: 1 item (id-at-organizationName=Let's Encrypt)
                                RelativeDistinguishedName item (id-at-organizationName=Let's Encrypt)
                                    Id: 2.5.4.10 (id-at-organizationName)
                                    DirectoryString: printableString (1)
                                        printableString: Let's Encrypt
                            RDNSequence item: 1 item (id-at-commonName=R3)
                                RelativeDistinguishedName item (id-at-commonName=R3)
                                    Id: 2.5.4.3 (id-at-commonName)
                                    DirectoryString: printableString (1)
                                        printableString: R3
                    subjectPublicKeyInfo
                        algorithm (rsaEncryption)
                            Algorithm Id: 1.2.840.113549.1.1.1 (rsaEncryption)
                        subjectPublicKey: 3082010a0282010100bb021528ccf6a094d30f12ec8d5592c3f882f199a67a4288a75d26…
                            modulus: 0x00bb021528ccf6a094d30f12ec8d5592c3f882f199a67a4288a75d26aab52bb9c54cb1af…
                            publicExponent: 65537
                    extensions: 8 items
                        Extension (id-ce-basicConstraints)
                            Extension Id: 2.5.29.19 (id-ce-basicConstraints)
                            critical: True
                            BasicConstraintsSyntax
                                cA: True
                                pathLenConstraint: 0
                        Extension (id-ce-keyUsage)
                            Extension Id: 2.5.29.15 (id-ce-keyUsage)
                            critical: True
                            Padding: 1
                            KeyUsage: 86
                                1... .... = digitalSignature: True
                                .0.. .... = contentCommitment: False
                                ..0. .... = keyEncipherment: False
                                ...0 .... = dataEncipherment: False
                                .... 0... = keyAgreement: False
                                .... .1.. = keyCertSign: True
                                .... ..1. = cRLSign: True
                                .... ...0 = encipherOnly: False
                                0... .... = decipherOnly: False
                        Extension (id-pe-authorityInfoAccess)
                            Extension Id: 1.3.6.1.5.5.7.1.1 (id-pe-authorityInfoAccess)
                            AuthorityInfoAccessSyntax: 1 item
                                AccessDescription
                                    accessMethod: 1.3.6.1.5.5.7.48.2 (id-ad-caIssuers)
                                    accessLocation: 6
                                        uniformResourceIdentifier: http://apps.identrust.com/roots/dstrootcax3.p7c
                        Extension (id-ce-authorityKeyIdentifier)
                            Extension Id: 2.5.29.35 (id-ce-authorityKeyIdentifier)
                            AuthorityKeyIdentifier
                                keyIdentifier: c4a7b1a47b2c71fadbe14b9075ffc41560858910
                        Extension (id-ce-certificatePolicies)
                            Extension Id: 2.5.29.32 (id-ce-certificatePolicies)
                            CertificatePoliciesSyntax: 2 items
                                PolicyInformation
                                    policyIdentifier: 2.23.140.1.2.1 (joint-iso-itu-t.23.140.1.2.1)
                                PolicyInformation
                                    policyIdentifier: 1.3.6.1.4.1.44947.1.1.1 (iso.3.6.1.4.1.44947.1.1.1)
                                    policyQualifiers: 1 item
                                        PolicyQualifierInfo
                                            Id: 1.3.6.1.5.5.7.2.1 (id-qt-cps)
                                            DirectoryString: http://cps.root-x1.letsencrypt.org
                        Extension (id-ce-cRLDistributionPoints)
                            Extension Id: 2.5.29.31 (id-ce-cRLDistributionPoints)
                            CRLDistPointsSyntax: 1 item
                                DistributionPoint
                                    distributionPoint: fullName (0)
                                        fullName: 1 item
                                            GeneralName: uniformResourceIdentifier (6)
                                                uniformResourceIdentifier: http://crl.identrust.com/DSTROOTCAX3CRL.crl
                        Extension (id-ce-subjectKeyIdentifier)
                            Extension Id: 2.5.29.14 (id-ce-subjectKeyIdentifier)
                            SubjectKeyIdentifier: 142eb317b75856cbae500940e61faf9d8b14c2c6
                        Extension (id-ce-extKeyUsage)
                            Extension Id: 2.5.29.37 (id-ce-extKeyUsage)
                            KeyPurposeIDs: 2 items
                                KeyPurposeId: 1.3.6.1.5.5.7.3.1 (id-kp-serverAuth)
                                KeyPurposeId: 1.3.6.1.5.5.7.3.2 (id-kp-clientAuth)
                algorithmIdentifier (sha256WithRSAEncryption)
                    Algorithm Id: 1.2.840.113549.1.1.11 (sha256WithRSAEncryption)
                Padding: 0
                encrypted: d94ce0c9f584883731dbbb13e2b3fc8b6b62126c58b7497e3c02b7a81f2861ebcee02e73…
            Extensions Length: 0
```
{{< /collapsible >}}

### ☁️ ➔ 💻 Certificate Verify (🔐)

> Because the server is generating ephemeral keys for each session (optional in TLS 1.2, mandatory in TLS 1.3) the session is not inherently tied to the certificate as it was in previous versions of TLS, when the certificate's public/private key were used for key exchange.
>
> To prove that the server owns the server certificate (giving the certificate validity in this TLS session), it signs a hash of the handshake messages using the certificate's private key. The signature can be proven valid by the client by using the certificate's public key. (\@XargsNotBombs)

{{< collapsible "Disassembly" >}}
```yaml
TLSv1.3 Record Layer: Handshake Protocol: Certificate Verify
    Content Type: Handshake (22)
    Version: TLS 1.2 (0x0303)
    Length: 264
    Handshake Protocol: Certificate Verify
        Handshake Type: Certificate Verify (15)
        Length: 260
        Signature Algorithm: rsa_pss_rsae_sha256 (0x0804)
            Signature Hash Algorithm Hash: Unknown (8)
            Signature Hash Algorithm Signature: Unknown (4)
        Signature length: 256
        Signature: 9adbef9d1b56a66dcd7e86eb8fbc826e66c3ea46802d757fc700576594835ad7bc66f1ad…
```
{{< /collapsible >}}

### ☁️ ➔ 💻 Finish (🔐)

The Finish contains verify data. A finished key is derived from the server\_handshake\_traffic\_secret ([RFC8446 4.4.4](https://tools.ietf.org/html/rfc8446#section-4.4.4])). This key is used to create an HMAC of the hash of the transcript of sent messages.

{{< collapsible "Disassembly" >}}
```yaml
TLSv1.3 Record Layer: Handshake Protocol: Finished
    Content Type: Handshake (22)
    Version: TLS 1.2 (0x0303)
    Length: 52
    Handshake Protocol: Finished
        Handshake Type: Finished (20)
        Length: 48
        Verify Data
```
{{< /collapsible >}}

### 💻 ➔ ☁️ Change Cipher Spec

This message if not encrypted and is only here for backward compatablity with TLS 1.2.

{{< collapsible "Disassembly" >}}
```yaml
TLSv1.3 Record Layer: Change Cipher Spec Protocol: Change Cipher Spec
    Content Type: Change Cipher Spec (20)
    Version: TLS 1.2 (0x0303)
    Length: 1
    Change Cipher Spec Message
```
{{< /collapsible >}}

### 💻 ➔ ☁️ Finished (🔐)

This is the first message which is encrypted using the client handshake keys and IVs like described in Server Hello. The verify data is constructed in the same way as the last Finished, just that client\_handshake\_traffic\_secret is used.

{{< collapsible "Disassembly" >}}
```yaml
TLSv1.3 Record Layer: Handshake Protocol: Finished
    Content Type: Handshake (22)
    Version: TLS 1.2 (0x0303)
    Length: 52
    Handshake Protocol: Finished
        Handshake Type: Finished (20)
        Length: 48
        Verify Data
```
{{< /collapsible >}}

### ☁️ ➔ 💻 New Session Ticket (🔐)

> The server provides a session ticket that the client can use to start a new session later. Successfully resuming a connection in this way will skip most of the computation and network delay in session startup.
>
> Because each session ticket is meant to be single-use, and because the server expects a browser to open multiple connections, it makes a size vs. speed decision to provide the client with two session tickets for each negotiated session. (\@XargsNotBombs)

One could think that the server just has a database of valid Session Ticket and looks them up if a ticket is received. This is not needed usually though. The server has a ticket encryption key $k_t$. When creating a ticket the server encrypts some pre shared key $psk$ with $k\_t$ and sends $enc(psk)$ and $psk$ to the client. When a session ticket is received the server can check it by decrypting $enc(psk)$ and comparing it with $psk$.

{{< collapsible "Disassembly" >}}
```yaml
TLSv1.3 Record Layer: Handshake Protocol: New Session Ticket
    Content Type: Handshake (22)
    Version: TLS 1.2 (0x0303)
    Length: 265
    Handshake Protocol: New Session Ticket
        Handshake Type: New Session Ticket (4)
        Length: 261
        TLS Session Ticket
            # Lifetime of this ticket
            Session Ticket Lifetime Hint: 300 seconds (5 minutes)
            # Milliseconds which have to be added to the generation date when sending this ticket back to the server. This prevents correlaction between the resumed session and the session which created this ticket.
            Session Ticket Age Add: 4125054233
            # A unique per ticket value
            Session Ticket Nonce Length: 8
            Session Ticket Nonce: 0000000000000000
            Session Ticket Length: 240
            # Data which is meaningful to the server to resume the session.
            Session Ticket: 85d9d71b78d02770ec876056db0e96cdb56cf40a05269064b9eb082759fdea509db4bca2…
            Extensions Length: 0
```
{{< /collapsible >}}

### ☁️ ➔ 💻 New Session Ticket (🔐)

An additional ticket for session resumption.

{{< collapsible "Disassembly" >}}
```yaml
TLSv1.3 Record Layer: Handshake Protocol: New Session Ticket
    Content Type: Handshake (22)
    Version: TLS 1.2 (0x0303)
    Length: 265
    Handshake Protocol: New Session Ticket
        Handshake Type: New Session Ticket (4)
        Length: 261
        TLS Session Ticket
            Session Ticket Lifetime Hint: 300 seconds (5 minutes)
            Session Ticket Age Add: 763549134
            Session Ticket Nonce Length: 8
            Session Ticket Nonce: 0000000000000001
            Session Ticket Length: 240
            Session Ticket: 85d9d71b78d02770ec876056db0e96cd3f58b452a549a597259c839dec496d4d37dc6296…
            Extensions Length: 0
```
{{< /collapsible >}}


### Application Data

For transmitting application data a new key is derived from the secrets. The procedure is similar to that in Server Hello. Just some other derivation function are used. See [RFC8446 4.4.4 - Master Secret](https://tools.ietf.org/html/rfc8446#section-4.4.4).

<!--
## PSK 1-RTT Authentification

## Used Primitives

## TLS 1.2 vs 1.3

## Attacks on TLS

## Why is Fuzzing necessary?

It is very difficult to have a formal model of TLS because of all the versions, extensions ambiguity of the RFC spec.
-->

[^1]: [Messy State of the Union]()
[^2]: [RFC8446 1.2](https://tools.ietf.org/html/rfc8446#section-1.2)