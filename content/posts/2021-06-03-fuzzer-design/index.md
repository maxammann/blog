---
layout: post
title: "tlspuffin: Design"
date: 2021-06-03
slug: fuzzer-design
draft: false

katex: true
hypothesis: true

keywords: []
categories: [research-blog]
---

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