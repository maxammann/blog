---
layout: post
title: "tlspuffin: Requirements"
date: 2021-04-21
slug: fuzzer-requirements
draft: false

katex: true

keywords: []
categories: [research-blog]
---

My symbolic-model guided fuzzer for OpenSSL has now a name. It is called `tlspuffin` and stands for **T**LS **P**rotocols **U**nder **F**uzz**IN**g.

The first implementation of the fuzzer will written in [Rust](https://www.rust-lang.org/) and be based on [LibAFL](https://github.com/AFLplusplus/LibAFL) [^1].
We will jump on to the Rust hype-🚆! That is actually beneficial for the project as the fuzzing community is currently testing the waters by using Rust for the implementation of fuzzing algorithms[^2].
LibAFL promises to provide a framework to build on top. It has a concept of Executors, Generators, Observers or Feedback which will be helpful when after designing how the input of the fuzzer will look like.

I went with OpenSSL as the first fuzzing target. There are multiple reasons for this decision. Rust is not able to call C++ libraries directly [^3]. That means [https://botan.randombit.net/](https://botan.randombit.net/) is not an ideal choice. While it would be possible to wrap Botan in a C library and then call that from Rust, it would involve quite some work.

Furthermore, there is plenty of documentation about OpenSSL available. A lot of people already have written Fuzzers for OpenSSL. There is also the [OpenSSL Wiki](https://wiki.openssl.org/index.php/Main_Page) which provides deeper insights in what each function does. There is also the `openssl` command line tool which comes preinstalled. This offers a quick and easy way to generate and parse keys or certificates or even start a simple OpenSSL server.

The compilation of OpenSSL is also very quick. On my machine it takes less than 1 minute to compile it. That means that it is easily possible to switch between OpenSSL versions or apply changes.

OpenSSL is also a high-value target, which means if we find a security problem, then it will impact a lot of people. This fact is also linked with another advantage of choosing OpenSSL as a target. It runs on a lot of architectures and is very portable. This means that the final POC of the fuzzer will most likely run on Mac and Linux which makes it easy to collaborate in a team working on the fuzzer.

Last but not least, the long history of vulnerabilities in OpenSSL allows us to benchmark the fuzzer easily. It is possible to jump back in time and see whether we can find already disclosed vulnerabilities.

## Architecture of the Fuzzer

Let's remember that we aim to fuzz OpenSSL on a protocol level. That means we try to find implementation bugs which lead to security issues on a logical level. Let's say for example that our TLS client uses a DH private key for authentication. Now the server receives that request via a `ClientCertificate` message. Because of an implementation bug the OpenSSL server allow the client to skip the usually mandatory `ClientCertificateVerify` message. This violates the authentication security, as the server thinks that the client is authenticated without proving that the client owns the private key to the sent certificate. This vulnerability actually existed in OpenSSL and is known as SKIP and CVE-2015-0205 [^4].

On a high level we try to build sane TLS messages. We do not try to produce invalid TLS packets which are not parsable. For example we are not trying to build TLS message, which contain only 4 extensions but the integer field in the message says that there are 10. This is not a sane TLS message. 
**Therefore, a sane TLS message is defined as being parsable. In this fuzzer we are aiming for logical flaws in implementations.**
Sending a TLS 1.3 `ClientHello` message without any extensions is a sane packet because it is parsable, even though the server will reject it as the Key Share extension is required in the latest version of TLS.

For used teminology refer to the [glossary]({{< ref "2021-04-24-tlspuffin-glossary" >}}) of tlspuffin.

### Modeling Capabilities of Attackers and Honest Agents 

**An attacker** is able to craft arbitrary traces. An attacker can generate variables, receive variables and combine them using function and therefore deduce new variables.
In an abstract way one could write:

$$ t_1 = (new(a_1, n), new(a_1, k), Send(a_1, encode(f(v_1, ... v_n))) $$

where $t_1$ is a trace which contains steps, 
$new(a, v)$ creates new local variable $v$ which is private to $a$,
$Send(a, d)$ publishes the bitstring $d$ from agent $a$ to the public channel and
$encode(d)$ creates a sane TLS message from the data $d$.

$f(v_1, ... v_n)$ is a chain of functions which a potential attacker can compute e.g. $f(v_1, ... v_n) = f(n,k) = enc(hash(n), k))$, where
$hash(d)$ hashes the data $d$ and 
$enc(d, k)$ encrypts data $d$ using the key $k$.

$hash$ and $enc$ are and example randomly chosen cryptographic functions for this trace. One could imagine to chain arbitrary functions together in order to create arbitrary TLS messages.

In reality some variables can be compromised but certain security properties would still hold. That means it would be interesting to see what an attacker does if secrets are compromised.

**Honest agents** are able to send message to the attacker, e.g. when the attacker is eavesdropping. They are also able to receive messages of the attacker. Honest agents in our fuzzer usually use the PUT like OpenSSL. Their implementation tries to follow the RFC spec. Let's extend the previous trace by appending steps:

$$ t_2 = (...t_1, Expect<ClientHello>(a_2)) $$

where 
$...$ spreads the previous trace and places the previous steps into $t_2$,
$Expect<ClientHello>(c)$ expects that $c$ receives a message of type $ClientHello$. If $c$ is the PUT, like OpenSSL then it would parse the received message, collection received variables and then send out the next message like a `ServerHello`.


This notation defines what is happening in the network of agents. It leaves a lot of freedom on how a concrete trace would look like. If we want to create concrete executions when we need to fix certain components:

* Define who receives messages (see [below](#message-passing-semantics))
* An attacker can choose an arbitrary $f$. We need a way of generating specific function chains for $f$.

#### Message Passing Semantics

In the previous traces we wrote that $Send(a_1, d)$ and described that it sends a message "to the public channel". This is of course arbitrary. This semantic makes sense in the case of MITM scenario, where the attacker has access to all messages. Now lets consider that the attacker is sitting on a ring bus part of a ring bus. 

{{< resourceFigure "ring.drawio.svg" >}}
Comparison of a ring and a star topology. The red symbol denotes an attacker. Once the attacker can only see traffic between two agents. In the other case the attacker can see all traffic in the network.
 {{< /resourceFigure >}}

 This means additionally to specifying who receives and sends messages, we also can define who is able to receive them. There are multiple ways of doing this:

 * Publish every message to every agent except one self (MITM)
 * Send message only to a specific agent (MITM)
 * Send message to the next client who will receives a message according to the trace. In the example above this could mean that $a_1$ sends only to $a_2$.
 * Send to the next two agents who will receive a message.

<!--
That's not exactly the way I saw this approach (that's might explain your comment above). Indeed, I don't see a notion of "honest agents" versus attacker here. Here is informally a grammar for something I had in mind:


message ::=
| new n [type] // adversary creates a new random n of "type" type (e.g., DH key, IDsession ,etc.)
| messageHandle // a messageHandle yields a message
| f(message_1,...,message_n) // apply any function symbol f (such as encyrption, hash, etc) to a series of messages

trace ::= action*

role ::= client | server

action ::=
  newAgent(role,idS)  // create a new agent playing role, identified by the session identifier idS (message of type IDsession)
| setValueHonest(idS,variable,value) // set the internal value of variable to value of the agent identified by idS
| in(idS, message) // send message to the agent identified by idS and make him parse and progress accordingly in the protocol (but stop before outputting anything)
| out(idS, messageHandle) // make the agent identified by idS send message and refer to this message with messageHandle

You can clearly see here the separation between 
(i) honest agents that process messages in an honest way (with in(idS...) and out(idS,...) and 
(ii) the adversary that can compute any message he wants (grammar of `message`) with the data he has gotten from honest agents' outputs (messageHandle), own keys and other kinds of random data (new), and through deduction capabilities (f(message_1....)). 

Note that the adversary does not have access to the random data generated and used by honest parties (like key). One could add some compromise capabilities where the adversary gets such data. Note, however, that the adversary can already simulate/execute fully compromised agents with through the computations of any message` (by applying the appropriate function symbols).

-->

#### From Abstract Traces to Concrete Traces

The above traces are quite abstract and are not easily executable. The idea for the fuzzer is to use the abstract definitions to generate very concrete traces. In the Practical Approach below I will show how to create concrete traces which are executable.
The generator and mutator of tlspuffin has the job of creating proper concrete traces.
There are two ways of doing this:

* Use an abstract model of traces and generate all (infinitely many) possible concrete traces. This means that because $f$ can be chosen arbitrary the attacker has an infinitely small change of guessing secrets like private keys.
* Start with a seed of some concrete traces. Mutate these to generate (infinitely many) more concrete traces.

Before going either direction we first have to focus on the execution and implementation of concrete traces.

### Practical Approach of Executing Concrete Traces

This is a very theoretical idea which I want to concretize now in order to implement it using Rust. The following diagram shows the terms which will be explained in the following.

{{< resourceFigure "class_diagram.drawio.svg" >}}
A diagram which shows the used concepts and how they are linked with each other. No methods or functions are shown, only data.
 {{< /resourceFigure >}}

A *Trace* consists of several *Steps*. Each has either an *Send-* or an *Expect-Action*. Each *Step* references an *Agents* by name. 
In case of a *Send* *Action* the *Agent* denotes: From which *Agent* a message is sent.
In case of an *Expect* *Action* the *Agent* denotes: Which *Agent* is expecting a message.

*Agents* represent communication participants like Alice, Bob or Eve. 
Each *Agent* has an *inbound* and an *outbound channel*. These are currently implemented by using an in-memory buffer.

One might ask why we need two channels. There two reasons for this:
* Having two buffers resembles how networking works in reality: Each computer has an send buffer and an receive buffer. In case of TCP the receive buffer can become full and therefore the transmission is throttled. 
* It is beneficial to model each agent with two buffers according to the Single-responsibility principle. When sending or receiving data each agent only has to look at its own two buffers. If each agent would have only one buffer then you would need to read from an other agent which has the data you want. Or if you design it the other way around you would need to write to the buffer of the agent to which you want send data.
* By having two buffers it is possible to define message passing semantics outside of the scope of the agents. The routine which is executing a trace can decide which message should be send to which agents.

The *Agent* Alice can add data to the *inbound channel* of Bob. Bob can then read the data from his *inbound channel* and put data in his *outbound channel*. If Bob is an OpenSSL *Agent* then then OpenSSL handles this.
Not the message passing semantics make sure that messages are fetched from agents and delivered to others.

An *Expect Action* can then verify whether the *inbound channel* contains the expected message and extract *VariableData* from it.

The implementation of this trace looks like this:

```rust
let trace = trace::Trace {
  steps: vec![
        Step {
            agent: dishonest_agent,
            action: &ClientHelloSendAction::new()
        },
        Step {
            agent: openssl_server_agent,
            action: &ServerHelloExpectAction::new()
        },
    ],
};
```

<!--
TODO How do you implement agents that do not follow the spec? 
-->
There are currently two different kinds of *Agents*. Firstly, a dishonest agent, which can craft arbitrary TLS messages and do not need to follow the RFC spec. Remember the arbitrary $f$ which can perform computations not defined in any RFCs.

Secondly, there are OpenSSL agents, which use OpenSSL to craft messages and respond to messages.

The *TraceContext* contains a list of *VariableData*, of which each has a *type* and an *owner*. *Send Actions* consume *VariableData*, whereas *Expect Actions* produce *VariableData*. *VariableData* can also be produced by initiating a *TraceContext* with predefined *VariableData*. *VariableData* can contain data of various types. For example client and server extensions, cipher suits, session ids etc.


## Functional Requirements

There are multiple components of the fuzzer like already shown in the [big picture]({{< ref "2021-04-06-symbolic-model-guided/#big-picture" >}}). In the previous section we discussed the implementation of the "Fuzzing Harness/Driver" and its interaction with the "Implementation" by creating "Concrete Traces".

The components which are missing as of now are:

- "Symbolic Traces Seed Pool" and "Mutate Symbolic Traces"
- "Execution Feedback"
- "Security Context" and "Bug Oracle"

Each of the components has specific requirements which we need to keep in mind. In this section we discuss whether which functional requirements each component has.

### Requirements: "Testing Harness" and "Implementation"

Our harness should allow us to maximize the amount of reached states, as well as the amount of "interesting" traces through the TLS protocol. In order to cover attack traces one can look at previously discovered implementation bugs of OpenSSL and see whether the testing harness can create an execution which triggers the bug.

Apart from triggering the bug we also want to be able to detect it. Therefore, here is a list of our first requirements (separated by horizontal rules):

---

Execute traces of known attacks against OpenSSL caused by implementation bugs. Example attacks are:
* SKIP → Skipping of messages
* Certificate Swapping → Replacing certificates via MITM
* Downgrade attacks → Caused by implementation bugs
* Selfie Attack → More generally reflection attacks

---

Detect known attack traces against OpenSSL like a violation of authentication or denial of service.

---

Agents can not only eavesdrop on messages but also change them. This is required to detect issues like in Needham-Schröder.

---

It must be possible to have more than two agents. The minimum is 3 agents which must be possible.

---

The PUT should be able to act as a TLS client and TLS server.

---

Variables owned by an agent must remain secret until they are sent out and love ownership.....

---

Data received during the execution must be available through variables.

---

It must be possible to do a complete TLS handshake between:
* a dishonest client (custom implementation in Rust) and an OpenSSL server (honest agent) and
* a dishonest server and an OpenSSL client and
* OpenSSL client and server to collect all the variables during the execution (testing scenario)
* OpenSSL client and server + a dishonest agent (MITM scenario)

It is not required that we can perform a handshake between two dishonest agents as in that case we would not test the PUT.

---

Ability to combine variables using explicit or random cryptographic functions. 

* Explicit: For example after the `ServerHello` the secret `client_handshake_traffic_secret` can be derived using the [Key Schedule in RFC 8446](https://tools.ietf.org/html/rfc8446#section-7.1). This secret must be stored as a *VariableData*.
* Random: Create *VariableData* out of random other *VariableData* and use it in fields of messages

---

Support key establishment through (resumption & external) pre-shared keys & 0-RTT mode. (Allows to model Selfie attack) 

---

 Possibility to share variables like PSK between one or multiple parties. Allow to declare that specific types of variables are shared.


### Requirements: "Symbolic Traces Seed Pool" and "Mutate Symbolic Traces"

---

The initial seed pool must allow the generation of infinitely many traces.

---

The generator of traces should favor those which are meaningful and reach deep states withing TLS.

---

Feedback of executions must be used to guide the mutations.

### Requirements: "Execution Feedback"

---

Executions must produce some kind of feedback. This could be achieved using instrumentation like coverage.

### Requirements: "Security Context" and "Bug Oracle"

---

The fuzzer should not only observe crashes, but also violations of security properties like authentication.

---

The bug oracle should be able to decide whether:
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