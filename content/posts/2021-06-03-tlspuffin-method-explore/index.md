---
layout: post
title: "tlspuffin: Methods for Exploring the State Space"
date: 2021-06-03
slug: tlspuffin-method-explore
draft: false

katex: true
hypothesis: true

keywords: []
categories: [research-blog]
---

After the last post we have now a framework to implement TLS traces and run them against OpenSSL or any other TLS implementation. There are now two main challenges which I want to cover in this post. But first let's define some terms.

**Protocol Specification** describes which features of the TLS specification and relevant extensions to the specification should be in scope of fuzzing. For TLS 1.3 the specification is [RFC 8446](https://datatracker.ietf.org/doc/html/rfc8446). In the case of TLS 1.2 the [RFC 5246](https://datatracker.ietf.org/doc/html/rfc5246) as well as several other RFCs for its extensions are part of the protocol specification. We maybe decide to exclude some features of TLS as they are not used at all in practice or are not worth fuzzing from a subjective perspective. An example for such a specification is [RFC 5081](https://datatracker.ietf.org/doc/html/rfc5081) which implements the possibility to use OpenPGP keys for authentication within the TLS protocol.
Secure renegotiation or `RSA_EXPORT` export ciphers may still be interesting to include, as servers might still support them, even through most clients won't request the features.


**Protocol Coverage** describes how much of the protocol specification, which has been set as a goal, is indeed covered by the fuzzer. The goal of tlspuffin is to reach complete protocol coverage. 

Note that 100% coverage according to the classical node coverage does not necessarily that we reached 100% protocol coverage. If the protocol specification describes a feature executes a specific action when the server receives a `ClientHello` or `Finished`, then we reached node coverage only by sending a `ClientHello`, but not yet protocol coverage as we did not send the `Finished` message. This is comparable to the fact that complete path coverage is not reached if node coverage is 100%. 

A **Symbolic Trace** describes an execution of a protocol (handshake) in a declarative way. Each step in the execution can either be an output or input step. If it is an output step, then information is added to the knowledge of the attacker. If it is an input step, then the attacker can decide which recipe term is passed to the PUT. Variables in the term are symbolic values and reference learned knowledge. Functions are defined by concrete implementations. Therefore, the recipe term is also called a **Symbolic Term**.

## Achieving High Protocol Coverage

Fuzzers test implementations by executing them repeatedly with different inputs. As tlspuffin works on a symbolical level and not on bit arrays the fuzzer has to be able to construct and evaluate symbolic terms. Evaluating these terms requires concrete implementations of function symbols. For example the function symbol `fn_client_hello` creates a TLS message which can be serialized to a binary data, which is ready to be sent to the TLS implementation. Below is an example for a term which builds a `ClientHello` message for TLS 1.2.

{{< resourceFigure "seed_client_attacker12_0.svg" >}}
Term which evalutes to a `ClientHello` TLS message.
{{< />}}

If we look at the previous example we can get the first ideas which capabilities need to be implemented, such that the fuzzer reaches high coverage.
Firstly, all message types for handshakes need to be implemented like `ClientHello` or `ServerHello`. If we take a look at the RFCs then there are several enumerations which list all types. There is the `ContentType` which specifies `change_cipher_spec`, `alert`, `handshake`, `application_data` and `heartbeat`. The alert and handshake messages specify further subtypes which also need to be covered.

Next there are the extensions. IANA provides a [list](https://www.iana.org/assignments/tls-extensiontype-values/tls-extensiontype-values.xhtml) of extensions and also specifies whether an extension is recommended. Note that if an extension is not recommended then it is not insecure, but did not go through the IETF consensus process. Covering all recommended extensions would be advisable.

To summarize, we should take a look at specified enumerations in RFC specs as well as external enumerations like the one of IANA for extensions. By implementing these function symbols, we can be sure confident that we can represent traces which trigger a security vulnerability.

Some enumerations might not be of interest like the `SignatureScheme` enumeration in the RFC specification of TLS 1.3, as one could argue that TLS implementations probably execute the same code for each schema just with slightly different arguments. In a nutshell we want to prioritize fuzzing the protocol logic implementation over fuzzing the underlying cryptographic library.
Nonetheless, the enumeration could be considered during fuzzing, just with less priority.

## Mutations

By implementing functions symbols for all features of the protocol specification is the first step. The next step is to mutate predefined seed traces to trigger security violations.

To do this we introduce the concept of mutators. A mutator is a function which maps a trace to another mutated trace. By looking at previous security issues of TLS implementations and implementing symbolic traces which lead to violations we can get an idea which mutations are necessary.
Furthermore, by implementing these traces manually we have a sanity check whether our fuzzer would have been able to represent the issue.

Beurdouche et al. introduced the three mutations **Skip**, **Hop** and **Repeat** [^1]. The first mutation skips a message. This could lead to authentication violations if for example a `CertificateVerify` message is skipped. The **Hop** combines two traces by taking a prefix from the first one and continuing with the second trace if it starts with the same prefix. **Repeat** injects messages into a trace by repeating previously sent ones.
Note that all these mutations work on a message level and do not mutate fields or extensions of messages.


Based on these ideas, we implement the following mutations, which mutate steps. We call these step mutators.

|Mutation|Description|
|---|---|
|SKIP|Removes an input step|
|REPEAT|Repeats an input which is already part of the trace|
|INJECT|Injects an input which is not part of the trace|

The following mutators mutate recipe terms which are part of input steps and therefore are called recipe mutators. The following mutators respect the type annotations within terms and are only performed if types of functions and variables match. These mutators extend the set of mutators which are currently state-of-the-art. By adding these mutators we are able to change fields within TLS message in contrast of just skipping and injecting whole messages.

Note that some mutators might are redundant. Replacing a sub-term could also be represented by a removal and addition of it. The rationale behind this is that certain mutations could be beneficial to happen after each other. Therefore, they are combined.

|Mutation|Description|
|---|---|
|REMOVE AND LIFT|Removes a sub-term from a term and attaches orphaned children to the parent (such that types match). This only works if there is only a single child.|
|REPLACE|Replace a function symbol (such that types match) and reuses other sub-terms as arguments if there are missing ones.|
|REPLACE-MATCH|Replaces a function symbol with a different one (such that types match). An example would be to replace a constant with another constant or the binary function `fn_add` with `fn_sub`.|
|REPLACE-REUSE|Replaces a sub-term with a different sub-term which is part of the trace (such that types match). The new sub-term could come from another step which has a different recipe term.|
|SWAP|Swaps a sub-term with a different sub-term which is part of the trace (such that types match).|

While swapping learned variables is already covered by the REPLACE-REUSE/SWAP mutation, variables an additional field which can be mutated: the observed ID.
The observed ID is the handle or reference to already learned knowledge. If knowledge is unused in a seed trace, then it first needs to be discovered by the fuzzer. Therefore, mutations need to exist, such that other observed IDs can be covered. The domain of the randomly generated IDs should be restricted as there are not infinitely many steps to reference.

|Mutation|Description|
|---|---|
|SWAP HANDLE|Changes the observed ID tuples to a randomly chosen one|



## Practical Problems to Overcome

There are several practical problems which make it difficult to implement concrete implementations in order to reach high protocol coverage.

Firstly, all messages and fields within messages need to be parsed and interpreted. Note, that in some cases we can leave a byte array uninterpreted. In this case the fuzzer will not mutate its internal structure, but will handle it is opaque data. A case in which this is required is encrypted data. Unlike plaintext, this data has no internal structure, before decrypting it.

To overcome this challenge of writing a parser for each and every message type we utilize [rustls](https://github.com/ctz/rustls) by forking it. This TLS library allows us to reuse parsing code. Unfortunately, some logical checks are included in the parsing. One example is that empty extension lists are rejected. The type system of Rust allows us to easily discover checks which return parsing errors and remove them.

Another issue with this TLS implementation is that it is not complete. Even though, it supports TLS 1.2 it does not support renegotiation. Furthermore, it does not yet support pre-shared keys in TLS 1.3. Therefore, careful review of the supported features is necessary, such that we can be sure that everything that should be parsable according to our protocol specification, is in fact parsable.

<!--
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




<!--
## Detecting Violations

TODO

### Denial of Service
### Authentication

* Detecting Authentication Violations between OpenSSL server (Bob) and client trace (Alice):
  * Expose a server public certificate
  * If we can make Alice think she is authenticated, then there is a vulnerability
-->

[^1]: [Messy State of the Union](https://www.ieee-security.org/TC/SP2015/papers-archived/6949a535.pdf)