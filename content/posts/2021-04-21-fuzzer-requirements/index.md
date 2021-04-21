---
layout: post
title: "Requirements for a Symbolic-model Guided Fuzzer for OpenSSL"
date: 2021-04-21
slug: fuzzer-requirements
draft: false

katex: true

keywords: []
categories: [research-blog]
---

The first implementation of the fuzzer will written in [Rust](https://www.rust-lang.org/) and be based on [LibAFL](https://github.com/AFLplusplus/LibAFL) [^1].
We will jump on to the Rust hype-🚆! That is actually beneficial for the project as the fuzzing community is currently testing the waters by using Rust for the implementation of fuzzing algorithms[^2].
LibAFL promises to provide a framework to build on top. It has a concept of Executors, Generators, Observers or Feedback which will be helpful when after designing how the input of the fuzzer will look like.

I went with OpenSSL as the first fuzzing target. There are multiple reasons for this decision. Rust is not able to call C++ libraries directly [^3]. That means [https://botan.randombit.net/](https://botan.randombit.net/) is not an ideal choice. While it would be possible to wrap Botan in a C library and then call that from Rust, it would involve quite some work.

Furthermore, there is plenty of documentation about OpenSSL available. A lot of people already have written Fuzzers for OpenSSL. There is also the [OpenSSL Wiki](https://wiki.openssl.org/index.php/Main_Page) which provides deeper insights in what each function does. There is also the `openssl` command line tool which comes preinstalled. This offers a quick and easy way to generate and parse keys or certificates or even start a simple OpenSSL server.

The compilation of OpenSSL is also very quick. On my machine it takes less than 1 minute to compile it. That means that it is easily possible to switch between OpenSSL versions or apply changes.

OpenSSL is also a high-value target, which means if we find a security problem, then it will impact a lot of people. This fact is also linked with another advantage of choosing OpenSSL as a target. It runs on a lot of architectures and is very portable. This means that the final POC of the fuzzer will most likely run on Mac and Linux which makes it easy to collaborate in a team working on the fuzzer.

## Architecture of the Fuzzer

Let's remember that we aim to fuzz OpenSSL on a protocol level. That means we try to find implementation bugs which lead to security issues on a logical level. Let's say for example that our TLS client uses a DH private key for authentication. Now the server receives that request via a `ClientCertificate` message. Because of an implementation bug the OpenSSL server allow the client to skip the usually mandatory `ClientCertificateVerify` message. This violates the authentication security, as the server thinks that the client is authenticated without proving that the client owns the private key to the sent certificate. This vulnerability actually existed in OpenSSL and is known as SKIP and CVE-2015-0205 [^4].

On a high level we try to build sane TLS messages. We do not try to produce invalid TLS packets which are not parsable. For example we are not trying to build TLS message, which contain only 4 extensions but the integer field in the message says that there are 10. This is not a sane TLS message. Sending a TLS 1.3 `ClientHello` message without any extensions is a sane packet, even though the server will reject it as the Key Share extension is required in the latest version of TLS.

### Theoretical Approach

Theoretically, we can achieve generating sane messages by chaining cryptographic functions together and in the end encoding this as a TLS packet. In an abstract way you could write:

$$ t = (new(n), new(k), Send(c_1, c_2, encode(enc(hash(n), k))), Expect(...)) $$

where $t$ is a trace, $new(v)$ creates new local variable $v$, $Send(c_1, c_2, d)$ sends the bitstring $d$ from client $c_1$ to $c_2$, $encode(d)$ creates a sane TLS message from the data $d$, $hash(d)$ hashes the data $d$ and $enc(d, k)$ encrypts data $d$ using the key $k$.

$hash$ and $enc$ are and example randomly chosen cryptographic functions for this abstract trace. One could imagine to chain arbitrary functions together in order to create arbitrary TLS messages.

### Practical Approach

This is a very theoretical idea which I want to concretize now in order to implement it using Rust. The following diagram shows the terms which will be explained in the following.

{{< resourceFigure "class_diagram.drawio.svg" >}}
A diagram which shows the used concepts and how they are linked with each other. No methods or functions are shown, only data.
 {{< /resourceFigure >}}

A *Trace* consists of several *Steps*. Each has either an *Send-* or an *Expect-Action*. Each *Step* references two *Agents* by name. 
In case of a *Send* *Action* the *Agents* denote respectively: *From* which *agent* *to* which *agent* a message is sent.
In case of an *Expect* *Action* the *Agents* denote: *From* which *agent* is the message expected and *to* which *agent* the message should be sent.

*Agents* represent communication participants like Alice, Bob or Eve. 
Each *Agent* has an *inbound* and an *outbound channel*. These are currently implemented by using an in-memory buffer. 

The *Agent* Alice can add data to the *inbound channel* of Bob. Bob can then read the data from his *inbound channel* and put data in his *outbound channel*. If Bob is an OpenSSL *Agent* then then OpenSSL handles this. An *Expect Action* can then verify whether the *outbound channel* contains the expected message and extract *VariableData* from it. After extracting the variables Bob adds the data from his *outbound channel* to the *inbound channel* of Alice.

The implementation of this trace looks like this:

```rust
let trace = trace::Trace {
  steps: vec![
        Step {
            from: dishonest_agent, to: openssl_server_agent,
            action: &ClientHelloSendAction::new()
        },
        Step {
            from: dishonest_agent, to: openssl_server_agent,
            action: &ServerHelloExpectAction::new()
        },
    ],
};
```

They can have different implementations of the TLS protocol and can be honest or dishonest. That means there are agents which follow the TLS specifications one some which don't.
There are currently two different kinds of *Agents*. Firstly, a dishonest agent, which can craft arbitrary TLS messages and an OpenSSL agent, which uses OpenSSL to craft messages and respond to messages. 

The *TraceContext* contains a list of *VariableData*, of which each has a *type* and an *owner*. *Send Actions* consume *VariableData*, whereas *Expect Actions* produce *VariableData*. *VariableData* can also be produced by initiating a *TraceContext* with predefined *VariableData*. *VariableData* can contain data of various types. For example client and server extensions, cipher suits, session ids etc.


## Functional Requirements

There are multiple components of the fuzzer like already shown in the [big picture]({{< ref "2021-04-06-symbolic-model-guided/#big-picture" >}}). In the previous section we discussed the implementation of the "Fuzzing Harness/Driver" and its interaction with the "Implementation" by creating "Concrete Traces".

The components which are missing as of now are:

- "Symbolic Traces Seed Pool" and "Mutate Symbolic Traces"
- "Execution Feedback"
- "Security Context" and "Bug Oracle"

Each of the components has specific requirements which we need to keep in mind. In this section we discuss whether which functional requirements each component has.

### Components: "Testing Harness" and "Implementation"

Our harness should allow us to maximize the amount of reached states, as well as the amount of "interesting" traces through the TLS protocol. In order to cover attack traces one can look at previously discovered implementation bugs of OpenSSL and see whether the testing harness can create an execution which triggers the bug.

Apart from triggering the bug we also want to be able to detect it. Therefore, we have our first two requirements:

> Execute traces of known attacks against OpenSSL caused by implementation bugs. Example attacks are:
> * SKIP → Skipping of messages
> * Certificate Swapping → Replacing certificates via MITM
> * Downgrade attacks → Caused by implementation bugs
> * Selfie Attack → More generally reflection attacks

---

Detect known attack traces against OpenSSL like a violation of authentication or denial of service.

More requirements:

> Agents can not only eavesdrop on messages but also change them. This is required to detect issues like in Needham-Schröder.

---

> It must be possible to have more than two agents. The minimum is 3 agents which must be possible.

---

> The PUT should be able to act as a TLS client and TLS server.

---

> Variables owned by an agent must remain secret.

---

> Data received during the execution must be available through variables.

---

> It must be possible to do a complete TLS handshake between:
> * a dishonest agent (custom implementation in Rust) and an OpenSSL client and
> * two OpenSSL clients and collect all the variables during the execution.
>
> It is not required that we can perform a handshake between two dishonest agents as in that case we would not test the PUT.

---

> Ability to combine variables using explicit or random cryptographic functions. 
>
> Explicit: For example after the `ServerHello` the secret `client_handshake_traffic_secret` can be derived using the [Key Schedule in RFC 8446](https://tools.ietf.org/html/rfc8446#section-7.1). This secret must be stored as a *VariableData*.
>
> Random: Create *VariableData* out of random other *VariableData* and use it in fields of messages

> Support key establishment through (resumption & external) pre-shared keys & 0-RTT mode. (Allows to model Selfie attack) 

 > Possibility to share variables like PSK between one or multiple parties. Allow to declare that specific types of variables are shared.

### Components: "Symbolic Traces Seed Pool" and "Mutate Symbolic Traces"

Requirements:

> The initial seed pool must allow the generation of infinitely many traces.

---

> The generator of traces should favor those which are meaningful and reach deep states withing TLS.

---

> Feedback of executions must be used to guide the mutations.

### Component: "Execution Feedback"

Requirements:

> Executions must produce some kind of feedback. This could be achieved using instrumentation like coverage.

### Components: "Security Context" and "Bug Oracle"

Requirements:

> The fuzzer should not only observe crashes, but also violations of security properties like authentication.

---

> The bug oracle must be able to decide whether an attack on
> * authentication,
> * replay or
> * (secrecy)
>
> happened.

[^1]: Not yet released as of writing
[^2]: Examples of Rust fuzzers: https://github.com/rust-fuzz
[^3]: [How to call a C++ dynamic library from Rust?](https://stackoverflow.com/questions/52923460/how-to-call-a-c-dynamic-library-from-rust)
[^4]: [Explanation of the CVE](https://security.stackexchange.com/questions/80113/openssl-vulnerability-cve-2015-0205); [Messy State of the Union](https://ieeexplore.ieee.org/document/7163046)