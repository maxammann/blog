---
layout: post
title: "tlspuffin: Requirements & Design"
date: 2021-05-11
slug: fuzzer-requirements
draft: false

katex: true
hypothesis: true

keywords: []
categories: [research-blog]
---

The first implementation of the fuzzer will written in [Rust](https://www.rust-lang.org/) and be based on [LibAFL](https://github.com/AFLplusplus/LibAFL) [^1].
We will jump on to the Rust Hype-🚆! That is actually beneficial for the project as the fuzzing community is currently testing the waters by using Rust for the implementation of fuzzing algorithms[^2].
LibAFL promises to provide a framework to build on top. It has a concept of Executors, Generators, Observers or Feedback which will be helpful when after designing how the input of the fuzzer will look like.

## Implementation Under Test

We are going with OpenSSL as the first fuzzing target. There are multiple reasons for this decision. Rust is not able to call C++ libraries directly [^3]. That means [https://botan.randombit.net/](https://botan.randombit.net/) is not an ideal choice. While it would be possible to wrap Botan in a C library and then call that from Rust, it would involve quite some work.

Furthermore, there is plenty of documentation about OpenSSL available. A lot of people already have written Fuzzers for OpenSSL. There is also the [OpenSSL Wiki](https://wiki.openssl.org/index.php/Main_Page) which provides deeper insights in what each function does. There is also the `openssl` command line tool which comes preinstalled. This offers a quick and easy way to generate and parse keys or certificates or even start a simple OpenSSL server.

The compilation of OpenSSL is also very quick. On my machine it takes less than 1 minute to compile it. That means that it is easily possible to switch between OpenSSL versions or apply changes.

OpenSSL is also a high-value target, which means if we find a security problem, then it will impact a lot of people. This fact is also linked with another advantage of choosing OpenSSL as a target. It runs on a lot of architectures and is very portable. This means that the final POC of the fuzzer will most likely run on Mac and Linux which makes it easy to collaborate in a team working on the fuzzer.

Last but not least, the long history of vulnerabilities in OpenSSL allows us to benchmark the fuzzer easily. It is possible to jump back in time and see whether we can find already disclosed vulnerabilities.

## Glossary

Let's quickly define a few terms we will use in this post.

|Term|Description|
|---|---|
|(Sane) TLS Message|A TLS message which is [parsable by rustls](https://github.com/ctz/rustls/blob/c44a1c90fa720255e6b46b0d2e6e7da65b1a7d8e/rustls/src/msgs/message.rs#L165). Rustls does not perform checks whether messages are logically valid. Therefore, we limit the input/output of tlspuffin to the parsing capabilities of rustls.|
|Honest Agent / Agent|An entity which runs a TLS client or server and is identified by a session identifier $s \in \mathcal{S}$. Agent which follows the TLS specification as implemented by the PUT (OpenSSL).|
|Attacker|The attacker controls the flow of tls messages and is able to eavesdrop on them. The attacker is more closely defined [here]({{< ref "2021-04-30-formal-mode-input.md" >}}/#modeling-the-attacker).|
|Trace|An extended trace as defined [here]({{< ref "2021-04-30-formal-mode-input.md" >}}/#traces).|
|Concretization of a Trace / Concrete Trace|The sequence of code instruction which is executed given a Trace.|
|Term|An term as defined [here]({{< ref "2021-04-30-formal-mode-input.md" >}}/#term-algebra).

## Fuzzing Idea

Let's remember that we aim to fuzz OpenSSL on a protocol level. That means we try to find implementation bugs which lead to security issues on a logical level. Let's say for example that our TLS client uses a DH private key for authentication. Now the server receives that request via a `ClientCertificate` message. Because of an implementation bug the OpenSSL server allow the client to skip the usually mandatory `ClientCertificateVerify` message. This violates the authentication security, as the server thinks that the client is authenticated without proving that the client owns the private key of the sent certificate. This vulnerability actually existed in OpenSSL and is known as SKIP and CVE-2015-0205 [^4].

On a high level we try to build sane TLS messages. We do not try to produce invalid TLS packets which are not parsable. For example, we are not trying to build TLS message, which contain only 4 extensions, but the integer field in the message says that there are 10. This is not a sane TLS message. 
**Therefore, a sane TLS message is defined as being parsable. In this fuzzer we are aiming for logical flaws in implementations.**
Sending a TLS 1.3 `ClientHello` message without any extensions is a sane packet because it is parsable, even though the server will reject it as the Key Share extension is required in the latest version of TLS.

We will use the formal model of the previous blog post. This model describes what and how an attacker can interact with agents. Before that we want to highlight two distinct approaches.

## Recap: Two Approaches for Fuzzing

When I initially started to work on the design of the fuzzer, there were two distinct approaches in my mind. The first is based on the architecture of [TLS-Attacker](https://github.com/tls-attacker/TLS-Attacker). The fuzzer generates traces of protocol flows. Like in TLS-Attacker the idea is that we implement a TLS client which can perform arbitrary computations and craft logically flawed but sane TLS messages.
To achieve this one can first create a happy protocol flow between the PUT and the custom TLS client. Based on this the mutator of the fuzzer can change the happy flow in various ways to yield traces which cause security violations.

**We do not want to follow this approach** as we can not base it on a sound theory. With the second approach, which is based on the formal model of the previous blog post, we can be sure that all attacks which exist are in the input space of the fuzzer. By basing the fuzzer on the theory of formal security protocol analysis we get a good framework which we can reason about formally.
## Practical Fuzzer Design

TODO describe design

This is a very theoretical idea which I want to concretize now in order to implement it using Rust. The following diagram shows the terms which will be explained in the following.

{{< resourceFigure "class_diagram.drawio.svg" >}}
A diagram which shows the used concepts and how they are linked with each other. No methods or functions are shown, only data.
 {{< /resourceFigure >}}

A *Trace* consists of several *Steps*. Each has either a *Send-* or an *Expect-Action*. Each *Step* references an *Agents* by name. 
In case of a *Send* *Action* the *Agent* denotes: From which *Agent* a message is sent.
In case of an *Expect* *Action* the *Agent* denotes: Which *Agent* is expecting a message.

*Agents* represent communication participants like Alice, Bob or Eve. 
Each *Agent* has an *inbound* and an *outbound channel*. These are currently implemented by using an in-memory buffer.

One might ask why we want two channels. There two very practical reasons for this. Note that these are advantages for the implementation and are not strictly required from a theoretical point of view.
* Having two buffers resembles how networking works in reality: Each computer has an input and an output buffer. In case of TCP the input buffer can become full and therefore the transmission is throttled. 
* It is beneficial to model each agent with two buffers according to the Single-responsibility principle. When sending or receiving data each agent only has to look at its own two buffers. If each agent had only one buffer, then you would need to read from another agent which has the data you want. Or if you design it the other way around you would need to write to the buffer of the agent to which you want to send data.
* By having two buffers it is possible to define a message passing semantic. The routine which is executing a trace can decide which message should be sent to which agents.

The *Agent* Alice can add data to the *inbound channel* of Bob. Bob can then read the data from his *inbound channel* and put data in his *outbound channel*. If Bob is an OpenSSL *Agent* then OpenSSL handles this.
Not the message passing semantics make sure that messages are fetched from agents and delivered to others.

An *Expect Action* can then verify whether the *inbound channel* contains the expected message and extract *VariableData* from it.

There are OpenSSL agents, which use OpenSSL to craft messages and respond to messages.

The *TraceContext* contains a list of *VariableData*, of which each has a *type* and an *owner*. *Send Actions* consume *VariableData*, whereas *Expect Actions* produce *VariableData*. *VariableData* can also be produced by initiating a *TraceContext* with predefined *VariableData*. *VariableData* can contain data of various types. For example client and server extensions, cipher suits, session IDs etc.
## Functional Requirements

There are multiple components of the fuzzer like already shown in the [big picture]({{< ref "2021-04-06-symbolic-model-guided/#big-picture" >}}). In the previous section we discussed the implementation of the "Fuzzing Harness/Driver" and its interaction with the "Implementation" by creating "Concrete Traces". These requirements are not expressed through formal definitions as they should stay informal to some extent. That way we do not restrict the design too far.

The components which are missing as of now are:

- "Symbolic Traces Seed Pool" and "Mutate Symbolic Traces"
- "Execution Feedback"
- "Security Context" and "Bug Oracle"

Each of the components has specific requirements which we need to keep in mind. In this section we discuss whether which functional requirements each component has.

### Requirements: "Testing Harness" and "Implementation"

**R1:** Our harness should allow us to maximize the amount of reached states, as well as the amount of "interesting" traces through the TLS protocol. In order to cover attack traces one can look at previously discovered implementation bugs of OpenSSL and see whether the testing harness can create an execution which triggers the bug.

Apart from triggering the bug we also want to be able to detect it. Therefore, here is a list of our first requirements (separated by horizontal rules):

---

**R2:** Execute traces of known attacks against OpenSSL caused by implementation bugs. Example attacks are:
* SKIP → Skipping of messages
* Certificate Swapping → Replacing certificates via MITM
* Downgrade attacks → Caused by implementation bugs
* Selfie Attack → More generally reflection attacks.

---

**R3:** Detect violations of authentication or denial of service against the PUT (OpenSSL).

---

**R4:** Agents can not only eavesdrop on messages but also change them. This is required to detect issues like in Needham-Schröder.

---

**R5:** It must be possible to have more than two agents. The minimum is 3 agents which must be possible.

---

**R6:** The PUT should be able to act as a TLS client and TLS server.

---

**R6:** Variables owned by an agent must remain secret until they are sent out

---

**R7:** Data received during the execution must be available to an agent later on.

---

**R8:** It must be possible to do a complete TLS handshake between:
* a dishonest client (custom implementation in Rust) and an OpenSSL server (honest agent) and
* a dishonest server and an OpenSSL client and
* OpenSSL client and server to collect all the variables during the execution (testing scenario)
* OpenSSL client and server + a dishonest agent (MITM scenario)

---

**R9:** Ability to combine data using explicit or random cryptographic functions. 

* Explicit: For example after the `ServerHello` the secret `client_handshake_traffic_secret` can be derived using the [Key Schedule in RFC 8446](https://tools.ietf.org/html/rfc8446#section-7.1). This secret must be stored as a *VariableData*.
* Random: Create *VariableData* out of random other *VariableData* and use it in fields of messages

---

**R10:** Support key establishment through (resumption & external) pre-shared keys & 0-RTT mode. (Allows modeling Selfie attack) 

---

**R11:** Possibility to share variables like PSK between one or multiple parties. Allow to declare that specific types of variables are shared.


### Requirements: "Symbolic Traces Seed Pool" and "Mutate Symbolic Traces"

---

**R12:** The initial seed pool must allow the generation of infinitely many traces.

---

**R13:** The generator of traces should favor those which are meaningful and reach deep states withing TLS. This can be achieved through a function which evaluates the feedback executions. 

### Requirements: "Execution Feedback"

---

**R14:** Executions must produce some kind of feedback. Feedback can be:

* Coverage data collected by instrumentation.
* Reported events/claims for detecting authentication violations.
* Data about crashes.
### Requirements: "Security Context" and "Bug Oracle"

---

**R15:** Based on the captured feedback in **R14**, the fuzzer should be able whether security violations have happened, like violation of authentication or a denial of service (crash).

---

**R16:** The bug oracle should be able to decide whether:
* an attack on authentication (and secrecy) has happened,
* messages were replayed,
* sessions were downgraded,
* both peers are on the same page about negotiated parameters (binding)
* conversations match [^5].


[^1]: Not yet released as of writing
[^2]: Examples of Rust fuzzers: https://github.com/rust-fuzz
[^3]: [How to call a C++ dynamic library from Rust?](https://stackoverflow.com/questions/52923460/how-to-call-a-c-dynamic-library-from-rust)
[^4]: [Explanation of the CVE](https://security.stackexchange.com/questions/80113/openssl-vulnerability-cve-2015-0205); [Messy State of the Union](https://ieeexplore.ieee.org/document/7163046)
[^5]: [Definition 4.1 (matching conversations)](https://cseweb.ucsd.edu/~mihir/papers/eakd.pdf)