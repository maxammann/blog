---
layout: post
title: "Distinction between Fuzzing Approaches for TLS"
date: 2021-04-12
slug: distinction-tls-fuzzing-approaches
draft: false

keywords: [ ]
categories: [ research-blog ]
---

This research blog focuses on novel ways to fuzz the TLS cryptographic protocol. Traditionally, fuzzing mutates bits and bytes. That means that the semantics of the protocol are not directly used to mutate the fuzzing input. [Symbolic-model Guided Fuzzing]({{< ref "2021-04-06-symbolic-model-guided" >}}) fuzzes on a more abstract level. It uses a symbolic model to create inputs. Therefore, there are two main approaches *bit-level fuzzing* and *model-guided fuzzing* (also called generation-based fuzzing) [^1]. This is also called [structure-aware fuzzing](https://github.com/google/fuzzing/blob/master/docs/structure-aware-fuzzing.md) by Google.

The classical example for a model which creates fuzz inputs is a grammar. A grammar of a programming language can directly generate syntactically correct programs encoded as text. Furthermore, such a grammar can generate abstract syntax trees (AST), which is just an encoding of the program which is easier to mutate. After mutating an abstract syntax tree it is possible to  serialize it to a text-file before passing it to the PUT. 

Note that an AST is similar indeed also a model. Therefore, one should differentiate between models which generate inputs (meta-model) and models which represent inputs.

## Bit-level Fuzzing

We will not dive into *bit-level fuzzing* as this evidence suggests that this technique is not able to create enough coverage paths which represent meaningful attack traces. <!-- TODO: Cite -->
This approach is not suitable for protocols, especially cryptographic ones. Later messages in a cryptographic protocol depend on random nonces generates in previous ones. That means it is very difficult to reach deep states. This is similar to overcome hash checks in traditional fuzzing. Note that checks against hashes are also used through-out TLS.


## Model-guided fuzzing

Now let's take a look at related approaches which use a model to fuzz TLS.

* [frankencerts](https://github.com/sumanj/frankencert)
  
  Generates "frankenstein" certificates for testing certificate validation
* [TLS-Attacker](https://github.com/tls-attacker/TLS-Attacker)

  Basically a TLS client which executes traces in configurable ways. Like: Send ClientHello with ECPointFormat and HeartbeatExtension. Expect ServerHello and Certificate messages from server. This allows to check for vulnerabilities like Heartbleed.
* [tlsfuzzer](https://tlsfuzzer.readthedocs.io/en/latest/testimonials.html)

  Allows one to create test-cases which send and expect TLS packets. *tlsfuzzer* can be run against a server to check for vulnerabilities like DROWN or ROBOT.
* ["Symbolic-Model-Aware Fuzzing of Cryptographic Protocols"](https://members.loria.fr/LHirschi/#teaching)

  Uses [IJON](https://github.com/RUB-SysSec/ijon) to guide the fuzzer. The input for the PUT is a binary file which represents an abstract execution trace. This trace is mutated by standard AFL methods. The execution is guided by IJON, which uses a scoring. 
* [flexTLS (abandoned)](https://mitls.org/pages/flextls) and [miTLS fstar (TLS 1.3)](https://github.com/project-everest/mitls-fstar)

  Similar to *tlsfuzzer* and *TLS-Attacker* as flexTLS also describes testcases for TLS communications.

*frankencerts* focuses only on the certificates and therefore it not really interesting when fuzzing a protocol as a whole. It could serve as a building block though to increase coverage.

*tlsfuzzer* and *TLS-Attacker* are quite similar in the sense that they offer a programmatic way to specify and execute traces. They don't focus on automated fuzzing though[^2]. They are more tools to define explicit test cases. They are not automatically creating interesting traces based on feedback of the PUT.
As they are implemented in Python and Java respectively it is also doubtful whether the code is usable in fuzzing because of performance reasons. Fuzzing usually requires a lot of runs to reach good edge or path coverage.
*TLS-Attacker* and *tlsfuzzer* offer a solid base to create test cases on which a fuzzer could be built. Unfortunately fuzzers traditionally are written in C/C++ and nowadays in Rust. Therefore, this could be an area in which preparation could be necessary.

*flexTLS* follows a similar approach. One difference is that *flexTLS* uses a verified core. But this also comes with the downside that the used languages F# and F* are rather obscure and not used in practical fuzzing. There are three major applications:

* implementing exploits for protocol and implementation bugs;
* automated fuzzing of various implementations of the TLS
* rapid prototyping of the TLS drafts.

The fuzzing is only basic though. For example the SmackTLS tool, which is based on flexTLS checks that deviant traces finish with an alert message and terminate properly [^4]. This is indeed very similar to *tlsfuzzer*: "While [tlsfuzzer] uses fuzzing techniques for testing (randomisation of passed in inputs), the scripts are generally written in a way that verifies correct error handling: unlike typical fuzzers it doesn't check only that the system under test didn't crash, it checks that it returned correct error messages."

 A *flexTLS* script looks like this[^3]:

```rust
let clientDHE (server:string, port:int) : state =
(*OfferonlyoneDHEciphersuite*)
let fch = {FlexConstants.nullFClientHello with 
ciphersuites = Some [DHE_RSA_AES128_CBC_SHA]} in 
(*Starthandshake*)
let st,nsc,fch = FlexClientHello.send(st,fch) in
let st,nsc,fsh = FlexServerHello.receive(st,fch,nsc ) in
let st,nsc,fcert = FlexCertificate.receive(st,Client,nsc) in
let st,nsc,fske = FlexServerKeyExchange.receiveDHE(st,nsc)
let st,fshd = FlexServerHelloDone.receive(st) in 
let st,nsc,fcke = FlexClientKeyExchange.sendDHE(st,nsc) in 
let st,_ = FlexCCS.send(st)in
...
```

The work about "Symbolic-Model-Aware Fuzzing" guides the fuzzer using the IJON. Clients and servers are represented by agents. The input of an abstract execution trace creates agents, does a handshake between them, creates messages and terms. Messages are then sent between the agents.
After each execution of a trace a score is calculated which is used to evaluate the run.
It is not possible to modify messages of the handshake. Therefore, there is still work to do in order to allow traces which diverge from the happy path.


In order to produce deviant attack traces one can not use a preexisting TLS library which is used in production as they try hard not to create invalid traces[^2]. That is their job in the first place.
The only exception I know so far is [rustls](https://github.com/ctz/rustls). It is quite easy to create and parse packets there. To serialize a message:

```rust

let message = Message {
    typ: RecordHandshake,
    version: TLSv1_2,
    payload: Handshake(HandshakeMessagePayload {
      typ: HandshakeType::ClientHello,
        payload: HandshakePayload::ClientHello(ClientHelloPayload {
            client_version: ProtocolVersion::TLSv1_3,
            random: Random::from_slice(&random),
            session_id: SessionID::new(&bytes),
            cipher_suites: vec![],
            compression_methods: vec![],
            extensions: vec![],
        }),
    }),
};
let mut out: Vec<u8> = Vec::new();
message.encode(&mut out);
hexdump::hexdump(&out);
```

To parse the same packet again:

```rust
coded_message = Message::read_bytes(out.as_slice()).unwrap();
decoded_message.decode_payload();
println!("{:?}", decoded_message);
```

The above mentioned approaches all go in the direction of a model guided Fuzzer. They are able to create and serialize messages, inject messages or leave them out and fill fields of message with arbitrary values. This is a very good start. What is missing here though is that no tool has a proper algorithm to generate deviant or happy traces and give feedback on them. They are very manual in the sense that they are not fuzzing tools but testing frameworks.


<!-- 
TODO Lucca:

The Three Dimensions of Fuzzing:

What you wrote is correct. Here are some more details that may interest you and that are not well covered in the fuzzing survey you cite:

* first dimension to categorize fuzzers: smart fuzzer (input structure aware) vs. dumb fuzzer (not aware of the input structure). Structure could be specified as grammar, formal specification, etc.
* second dimension: generation-based fuzzer vs. mutation-based fuzzer. The first one corresponds to fuzzers that do not need an initial seed pool but that instead use a description of the input space to generate inputs from scratch. The second may not have a specification of the input space but uses instead a seed pool corresponding to many valid executions (e.g., unitary tests, happy flow in a protocol), mutations will then be used to generate new test cases. Note that generation-based fuzzers may also use mutations to mutate test cases generated before or mutated before.
* white-box/gray-box/black-box fuzzers (should be self-explanatory).

In the survey they "define" model-based as smart+generation-based.
That is fine and you don't need to modify your write-up.
-->

<!--
## Limitations of TLS Attacker

## Protobuf as binary format between Rust and OpenSSL
-->

## Other projects in this direction

* [tlsbunny](https://github.com/artem-smotrakov/tlsbunny)

[^1]: [The Art, Science, and Engineering of Fuzzing: A Survey](https://arxiv.org/abs/1812.00140)
[^2]: [TLS Test Framework How to check if your SSL server is standards compliant and client compatible](https://youtu.be/fChzF_UkAGc?t=450)
[^3]: [flexTLS p. 4](https://hal.inria.fr/hal-01295035/document)
[^4]: [flexTLS Section 3.2](https://hal.inria.fr/hal-01295035/document)