---
layout: post
title: "tlspuffin: Design"
date: 2021-06-01
slug: fuzzer-design
draft: false

katex: true
hypothesis: true

keywords: []
categories: [research-blog]
---

The theoretical model as discussed in a [previous]({{< ref "2021-04-30-tlspuffin-formal-model" >}}) post. Based on this formal model the following implementation was designed. Firstly, we will give a broad overview in a diagram which shows the relations between the used concept

{{< resourceFigure "class_diagram.drawio.svg" >}}
tlspuffin consists of several modules: the root, *term*, *fuzzer* and *tls* module.

The root module contains *Traces* consisting of several *Steps*, of which each has either an *OutputAction* or *InputAction*. This is a declarative way of modeling communication between *Agents*. The *TraceContext* holds data, also known as *VariableData*, which is created by *Agents* during the concrete execution of the Trace. It also holds the *Agents* with the references to concrete PUT

The *term* module defines typed terms of the form `fn_add(x: u8, fn_square(y: u16)) → u16`. Each function like `fn_add` or `fn_square` has a shape. The variables `x` and `y` each have a type. These types allow type checks during the runtime of the fuzzer. These checks restrict how terms can be mutated in the *fuzzer* module.

The *fuzzer* module setups the fuzzing loop. It also is responsible for gathering feedback from runs and restarting processes if they crash.

The *tls* module provides concrete implementations for the functions used in the term The module offers a variety of *DynamicFunctions* which can be used in the fuzzing.
 {{< /resourceFigure >}}

A *Trace* consists of several *Steps*. Each has either a *OutputAction* or an *InputAction*. Each *Step* references an *Agent* by name. Furthermore, a trace also has a list of *AgentDescritptors* which act like a blueprint to spawn *Agents* with a corresponding server or client role and a specific TLs version. Essentially they are an *Agent* without a stream. 

*Agents* represent communication participants like Alice, Bob or Eve. Attackers are usually not represented by these *Agents*. Attackers are represented through a recipe term (see *InputAction*).

Each *Agent* has an *inbound* and an *outbound channel*. These are currently implemented by using an in-memory buffer. One might ask why we want two channel There two very practical reasons for thi Note that these are advantages for the implementation and are not strictly required from a theoretical point of view.
* Having two buffers resembles how networking works in reality: Each computer has an input and an output buffer. In case of TCP the input buffer can become full and therefore the transmission is throttled. 
* It is beneficial to model each agent with two buffers according to the Single-responsibility principle. When sending or receiving data each agent only has to look at its own two buffer If each agent had only one buffer, then you would need to read from another agent which has the data you want. Or if you design it the other way around you would need to write to the buffer of the agent to which you want to send data.

The *Agent* Alice can add data to the *inbound channel* of Bob. Bob can then read the data from his *inbound channel* and put data in his *outbound channel*. If Bob is an *Agent*, which has an underlying *OpenSSLStream* then OpenSSL may write into the *outbound channel* of Bob.

An open question is how the two action types *OutputAction* and *InputAction* differ.
Both actions drive the internal state machine of an *Agent* forward by calling `next_state()`. The *OutputAction* first forwards the state machine and then extracts knowledge from the TLS messages produced by the underlying stream by calling  `take_message_from_outbound(...)`. The *InputAction* evaluates the recipe term and injects the newly produced message into the *inbound channel* of the *Agent* referenced through the corresponding *Step* by calling `add_to_inbound(...)` and then drives the state machine forward.
Therefore, the difference is that one step *increases* the knowledge of the attacker, whereas the other action *uses* the available knowledge.


The *TraceContext* contains a list of *VariableData*, which is known as the knowledge of the attacker. *VariableData* can contain data of various types like for example client and server extensions, cipher suits or session ID It also holds the concrete references to the *Agents* and the underlying stream

## Traces

After discussing the core concepts, we want to take a look on how to declare a trace. A trace is a declarative way of defining the information flow between agent The simplest example just forwards messages between a client and a server. The following example describes a client and a server agent and a series of step The first step makes the client output a `ClientHello` message. After that we send a `ClientHello` to the server agent and let the server output messages. The next step then sends a `ServerHello` to the client. To forward the messages we construct `ClientHello` and `ServerHello` messages from the knowledge gathered during the output steps. A variable like `new_var::<ProtocolVersion>((0, 0))` references a `ProtocolVersion` learned in the first message of the first step. A variable like `new_var::<CipherSuite>((1, 0))` references a `CipherSuite` learned in the first message of the second step. We also call the tuple an `ObservedId`. This is necessary as referencing learned knowledge only by a type is often ambiguous. By using the observed IDs we can limit this problem.

```rust

let client: AgentName = ...;
let server: AgentName = ...;

Trace {
        descriptors: vec![
            AgentDescriptor {
                name: client,
                tls_version: TLSVersion::V1_3,
                server: false,
            },
            AgentDescriptor {
                name: server,
                tls_version: TLSVersion::V1_3,
                server: true,
            },
        ],
        steps: vec![
            Step { agent: client, action: Action::Output(OutputAction { id: 0 })},
            // Client: Hello Client -> Server
            Step {
                agent: server,
                action: Action::Input(InputAction {
                    recipe: Term::Application(
                        new_function(&fn_client_hello),
                        vec![
                            Term::Variable(new_var::<ProtocolVersion>((0, 0))),
                            Term::Variable(new_var::<Random>((0, 0))),
                            Term::Variable(new_var::<SessionID>((0, 0))),
                            Term::Variable(new_var::<Vec<CipherSuite>>((0, 0))),
                            Term::Variable(new_var::<Vec<Compression>>((0, 0))),
                            Term::Variable(new_var::<Vec<ClientExtension>>((0, 0))),
                        ],
                    ),
                }),
            },
            Step { agent: server, action: Action::Output(OutputAction { id: 1 })},
            // Server: Hello Server -> Client
            Step {
                agent: client,
                action: Action::Input(InputAction {
                    recipe: Term::Application(
                        new_function(&fn_server_hello),
                        vec![
                            Term::Variable(new_var::<ProtocolVersion>((1, 0))),
                            Term::Variable(new_var::<Random>((1, 0))),
                            Term::Variable(new_var::<SessionID>((1, 0))),
                            Term::Variable(new_var::<CipherSuite>((1, 0))),
                            Term::Variable(new_var::<Compression>((1, 0))),
                            Term::Variable(new_var::<Vec<ServerExtension>>((1, 0))),
                        ],
                    ),
                }),
            },
            ...
        ]
}
```

As this syntax is very verbose, we can use Rust to create a DSL[^1]. 

```rust
OutputAction::new_step(client, 0),
// Client Hello, Client -> Server
InputAction::new_step(
    server,
    term! {
        fn_client_hello(
            ((0, 0)/ProtocolVersion),
            ((0, 0)/Random),
            ((0, 0)/SessionID),
            ((0, 0)/Vec<CipherSuite>),
            ((0, 0)/Vec<Compression>),
            ((0, 0)/Vec<ClientExtension>)
        )
    },
),
OutputAction::new_step(server, 1),
// Server Hello, Server -> Client
InputAction::new_step(
    server,
    term! {
        fn_server_hello(
            ((1, 0)/ProtocolVersion),
            ((1, 0)/Random),
            ((1, 0)/SessionID),
            ((1, 0)/CipherSuite),
            ((1, 0)/Compression),
            ((1, 0)/Vec<ServerExtension>)
        )
    },
),
...
```


After declaring a trace we can execute it by creating a context, spawning the agents and then calling `execute()`.

```rust
let trace = ...;
let mut ctx = TraceContext::new();
trace.spawn_agents(&mut ctx)?;
trace.execute(&mut ctx)?;
```

Note that `spawn_agents` and `execute` can fail. This does not necessarily indicate a crash of the PUT, but can also mean that encryption or decryption of authenticated data failed in a step.

The above snippet is actually our fuzzing harness. In each fuzzing loop we spawn agents and execute the trace. After each execution, we have the possibility to gather feedback from the run as well as to mutate the trace. The harness is implemented in the file `src/fuzzer/harness.rs`.

### Serializability

Each trace is serializable to JSON or even binary data. This helps at reproducing discovered security vulnerabilities during fuzzing. If a trace triggers a security vulnerability we can store it on disk and replay it when investigating the case.

## Concrete implementations

Rust is a statically typed language. That means the compiler would be able to statically verify that a term evaluates without any type errors.

While this is generally an advance, in the case of our fuzzer this is not very helpful. The fuzzer should be able to mutate the term trees arbitrarily. Of course, we also have to check for the types during runtime. If types are not compatible then, the evaluation of the term will fail. But this is not something that can be done during compile time. Therefore, we introduced a trait for dynamically typed functions on top of statically typed Rust functions.

Each function which implements the following trait can be made into a dynamic function:

```rust
Fn(A1, A2, A3) -> Result<R, FnError>)
```

where `A1`, `A2`, `A3` are argument types and `R` is the return type. From these statically typed function we can generate dynamically types ones which implement the following trait:

```
pub trait DynamicFunction: Fn(&Vec<Box<dyn Any>>) -> Result<Box<dyn Any>, FnError> {
}
```

Note, that both functions return a `Result` and therefore can gracefully fail.

`DynamicFunctions` can be called with an array of any type. The result type is also arbitrary. Rust offers a unique ID for each type. Using this type we can check during runtime whether types are available. The types of each variable, constant and function are preserved and stored alongside the `DynamicFunction`.

The following function is a simple example for a constant:

```rust
pub fn fn_cipher_suites() -> Result<Vec<CipherSuite>, FnError> {
    Ok(vec![CipherSuite::TLS13_AES_128_GCM_SHA256])
}
```


TODO:

* feedback, sancov



[^1]: [A DSL embedded in Rust](https://dl.acm.org/doi/10.1145/3310232.3310241)