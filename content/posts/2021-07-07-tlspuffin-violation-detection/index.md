---
layout: post
title: "tlspuffin: Security Violations"
date: 2021-07-07
slug: tlspuffin-violation-detection
draft: false

katex: true
hypothesis: true

keywords: []
categories: [research-blog]
---

The goal of tlspuffin is to find logical security vulnerabilities within TLS implementations. A security vulnerability violates a security property of TLS. This could be for example Confidentiality, Integrity or Authentication ([more](https://www.davidwong.fr/tls13/#appendix-E)).

For example a downgrade attack against OpenSSL like FREAK, does not expose the plaintext of the communication directly, but allows an arbitrary attacker with common computation power to factorize the RSA key and therefore break the encryption.

These kinds of logical attacks do not crash the implementation. A crash is also not desirable by an attacker because it represents a Denial-of-Service attack. If the goal of the attacker is to eavesdrop on a connection, then she has to find a logical attack like FREAK.

Usually fuzzers try to find crashes of implementations. These are easily detectable because the process which executes the library crashes. A security violation is more difficult to check as we need to introduce invariants which hold during the execution of a handshake. In the following we try to give some ideas over which variables such variants could be defined.

## Queries and Traces of Claims

To check for security violations we introduce the concept of claims, which are also known as events. A claim has a name, an executing agent, as well as data attached to it. For example during the execution of a successful TLS 1.3 handshake the claim `Finished(client, master_secret)` is recorded. That means that the honest agent `client` has reached the protocol state in which the finished the handshake. The additional data `master_secret` can be used in security queries.

Let's compare a query with events from ProVerif with our notion of queries and claims. The following query demands that if the client reached a state in which it is finished, that the corresponding server should already have finished. This query is a sanity check and does not check security properties.

```kotlin
query cr:random, sr:random, 
      psk:preSharedKey,p:pubkey,o:params, m:params, 
      ck:ae_key, sk:ae_key, cb:bitstring, ms:bitstring;
      event(ClientFinished(TLS12,cr,sr,psk,p,m,o,ck,sk,cb,ms)) ==>
      event(ServerFinished(TLS12,cr,sr,psk,p,m,o,ck,sk,cb,ms)).
```

The query also makes sure that server and client both have negotiated the same parameters as versions and keys.

ProVerif proves that for all traces of the protocol the above query is true. In the case of tlspuffin we only need to check queries for a single trace.

Let's suppose that the execution of a TLS 1.3 handshake in tlspuffin yields the following trace:

`ClientHello(client, ...)`, `ServerHello(server, ...)`, `Certificate(server, ...)`, `CertificateVerify(server, ...)`, `Finished(server, ...)`, `Finished(client, ...)`

We are logging the internal state of the state machine when the implementation is constructing a TLS message, as well as when it is receiving and processing a message. This is required because TLS provides security properties after each message. For example if the construction of a `Certificate` message causes a security violation, then this violation is maybe only detectable before constructing the next message `CertificateVerify`.
Furthermore, our goal is to fuzz the application layer of the TLS protocol not the record layer. The record layer can introduce fragmentation and therefore can decide how to bundle flights of messages. If we only log security claims after flights, we can not be sure at which state of the protocol we are. Therefore, we need to log the security claims after each message.

## Ideas for Queries

|Vulnerability|TLS Version|Type|Detection Method|
|---|---|---|---|
|SKIP EXCHANGE|1.2|MITM Impersonation|??|
|SKIP VERIFY|1.2|Client Attacker|Check whether it is possible to authenticate without private key|
|SKIP EPHEMERAL|1.2|MITM Downgrade|Check whether best option was chosen|
|FREAK|1.2|MITM Downgrade|Check whether best option was chosen|
|Selfie|1.3|??|??|

### 1.3 Key Shares

* the server's key share MUST be in the same group as one of the client's shares (https://hypothes.is/a/1jdqEMHcEeuQN-vVtD7B9A)
### Check whether best option was chosen AKA detect Downgrade (FREAK)

When (public)-keys are used for encrypting secrets we can check whether the cipher suite is weak. A used cipher suite is weak if it is not the best option between two peers. A client offers a set of ciphers $L_c$ and the server also has a set of supported ciphers $L_s$. The best option which satisfies both peers is to use the best cipher of the partially ordered set $L_c \cap L_s$. 

In our fuzzer we always have access to the ciphers which clients or server will support. We also have a partial order over all ciphers. This means whenever a key is generated which is weaker than the best option, then we have a security violation, which corresponds to a downgrade attack.

By doing this we can easily detect FREAK for example. In FREAK the client does not need to support an export cipher. A man-in-the-middle can trick the client in using one though. Even if the client would support export ciphers, then an export cipher is not the best option, which is also a security violation.

This is possible because some export ciphers require a temporary/ephemeral RSA key: https://www.ietf.org/rfc/rfc2246.html#appendix-D.1

This check can also be implemented using a security query. By looking at a trace we can compute the best cipher, which both peers support. The trace should also issue a claim when a key is generated or used. If the used or generated key is weaker than the best option then we have a security violation.

In practice this is more difficult. Only export cipher suites have a mandatory maximum key length: https://datatracker.ietf.org/doc/html/rfc2246#appendix-C
This means that only downgrades to export ciphers are detectable by this method.
It is not easily possible to detect the usage of an export cipher on the client side like this, because the client is never aware that it is used a weak cipher.

#### Further Example

"V-C SKIP EPHEMERAL: FORWARD SECRECY ROLLBACK" is also a downgrade attack from an ephemeral key exchange to a static one. Even though both peers support ephemeral key exchanges a MITM can trick the peers into using their static keys. This is simply done by skipping the `ServerKeyExchange` message. 

* After a successful handshake we could check which key exchange method was used and compare it to the best key exchange method which is supported by both peers. If it is weaker, then we witnessed a downgrade attack.

* During the handshake we could check whether static keys are used, even though this should not be possible because the intersection of the supported ciphers of both peers do not support this kind of key exchange.

### Channel Binding/Agreement

After a successful handshake we can check whether both peers negotiated the same parameters for the connection. For example if the client uses the cipher suite `TLS_RSA_WITH_AES_256_CBC_SHA256`, but the server uses `TLS_RSA_EXPORT_WITH_DES40_CBC_SHA` and both peers perform a successful handshake, then we have a security violation. In case of FREAK this is only possible if the attacker can factorize a 512bit RSA key. When fuzzing we could suppose that for every 512bit public RSA key, the private key is known.


According to paper "Verified Models and Reference Implementations for the TLS 1.3 Standard Candidate" Aggreement/Authentication is defined as:

> Authentication: If an application data message $m$ is received over a session $cid$ from an honest and authenticated peer, then the peer must have sent the same application data m in a matching session (with the same parameters $cid$, $offer_C$, $mode_S$, $pk_C$, $pk_S$, $psk$, $k_c$, $k_s$, $psk'$).

$psk$ and $psk'$ are ignored for now as we are not fuzzing handshakes which include session resumption. This is left open for further work.

We are checking this property by comparing the mentioned parameters after the handshake finished successfully. $offer_C$ and $mode_S$ respectively include 
the protocol version $ver_C$ and $ver_S$,
the key exchange protocol $kex_C$ $kex_S$,
the Diffie-Hellman group (if applicable) $dhg_C$ $dhg_S$,
the authenticated encryption scheme $enc_C$ $enc_S$,
the signature and hash algorithms $sig_C$, $sig_S$ and $hash_C$, $hash_S$.

<!-- Furhter paramters:

* Available ciphers,
* Certificates

-->

In terms of OpenSSL the above parameters correspond to the following implementation concepts:

|Parameter|TLS version|Implementation|Description|
|---|---|---|---|---|
|$cid$|1.3|`s->tmp_session_id`|The session ID is available at both peers after the initial `ServerHello`.|
|$cid$|1.2|`s->session->session_id`|-|
|$ver_x$|1.3/1.2|`s->version`|-|<!-- Cipher related -->
|$enc_x$|1.3/1.2|`s->s3->tmp.new_cipher`|Can be derived from the cipher, because the cipher determines the encryption algorithm.|
|$hash_x$|1.3/1.2|`s->s3->tmp.new_cipher`|Can be derived from the cipher, because the cipher determines the hashing algorithm.|<!-- NOT cipher related-->
|$sig_x$|1.3/1.2|`s->s3->tmp.sigalg` and `s->s3->tmp.peer_sigalg`|The signature algorithm is not determined by the cipher suite in TLS 1.3. This data is therefore captured from the Signature Algorithms extension.|
|$kex_x$|1.3|`match_key_type(SSL_get_tmp_key(s))` or `s->s3->group_id`|The key exchange algorithm is not determined by the cipher suite in TLS 1.3. It can be only an ephemeral key exchange as static ones have been removed due to the lack of forward secrecy. The key exchange is negotiated through the Key Share extension.|
|$kex_x$|1.2|`s->s3->tmp.new_cipher`|`s->s3->tmp.new_cipher`|Can be derived from the cipher, because the cipher determines the hashing algorithm.|
|$dhg_x$|1.2|`match_key_type(SSL_get_tmp_key(s))`|The group for DH and ECDH is negotiated via the `ServerKeyExchange` message in `tls_construct_server_key_exchange`. **For 1.2 `SSL_get_tmp_key(s)` return NULL after the key exchange happened.**|
|$dhg_x$|1.3|`match_key_type(SSL_get_tmp_key(s))` or `s->s3->group_id`|The group is negotiated through the Key Share and Supported Groups extension. It is set in the function `tls_parse_ctos_key_share`.|<!-- Secretes -->
|$k_x$|1.3|`s->client_app_traffic_secret` and `s->server_app_traffic_secret`|Secrets which are used to encryption the application data after the handshake.|
|$k_x$|1.2|`s->session->master_key`|Secret from which the final write keys are derived.|
|$pk_x$|1.3/1.2|`SSL_get_tmp_key(s)` and `SSL_get_peer_tmp_key(s)`|Gets the keys used for an ephemeral handshake. Can be private or public RSA, DH or ECDH keys. **For 1.2 `SSL_get_tmp_key(s)` return NULL after the key exchange happened.**|



### Check whether it is possible to authenticate without private key (SKIP)

The client authenticates with the server. The client skips the `CertificateVerify` message and still is authenticated. This could be checked by not providing the client with the private key, but just the public key for an authentication certificate.

The setup could be:
1. two honest agents which do client authentication, then SKIP one message and not use the private key, requires detecting non-usage
1. one attacker client and one honest server, then provide the client attacker with a wrong private key. Providing the client or server with a key could happen through initial knowledge.
    * If we suppose that the client is not authenticated, because he is an attacker, and the server claims that the client is authenticated, then we have a security violation.
    * Practically we simply fuzz the client attacker and setup the server such that it requires authentication.

## Implementation

We want to do most of the checks in the testing harness which is implemented in Rust. A unified interface should make it possible that the same invariants can be used across different implementations like LibreSSL and OpenSSL, but also between OpenSSL versions like 1.0.x and 1.1.1.



