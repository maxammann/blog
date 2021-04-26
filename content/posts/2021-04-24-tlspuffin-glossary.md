---
layout: post
title: "tlspuffin: Glossary"
date: 2021-04-24
slug: tls-puffin-glossary
draft: false

keywords: []
categories: [research-blog]
---

In the previous posts we already used some terms quite loosely. Therefore I present a glossary in this post.


|Term|Description|
|---|---|
|Sane Message|A TLS message which is parsable.|<!-- I understand it thanks to our last discussion. However, to make this a bit more formal, I suggest you explain to which thing the packet should be parsed: TCP payload? TLS structured payload? Valid TLS message? I think the closest to what you mean is the second option. Formally, a grammar for TLS structured payload could be given, or a reference to it would be OK too. For instance in your code, "parsable" means it can be decoded as a rustls::internal::msgs:message::Message, whose "grammar" is defined [here(https://github.com/ctz/rustls/blob/c44a1c90fa720255e6b46b0d2e6e7da65b1a7d8e/rustls/src/msgs/message.rs#L165). Is that right? -->
|Agent|An entity which runs a TLS client or server|
|Honest Agent|Agent which aims to follow the TLS spec and avoid security violations.| <!--"Honest agents: Agent which aims to follow the TLS spec and avoid security violations." -> imprecise (aim to, avoid security violations...). More formally, honest agents = follow the spec. In your case: follow the spec as implemented in some chosen PUT (here OpenSSL).-->
|Dishonest Agent|Agent which does not follow the TLS spec but sends Sane Messages|<!--	Is the difference between dishonest agents and attacker relevant? -->
|Attacker|A dishonest Agent which aims to violate security properties of other Honest Agents|
|Concrete Trace|Sequence of Sane Messages between Agents. They are concrete in the sense that each execution yields the exact same behavior, under the assumption that the PUT is deterministic.|
|Happy Trace|Concrete Trace between two Honest Agents which does not violate security properties| <!-- So there are many such traces? What about concrete traces that do not violate explicitly given security properties but other properties that were not given as security goals? Maybe you rather want to define this along the lines of "...between two honest agents only, with a trusted network (hence without attacker/dishonest agent)". -->
|Attack Trace|Concrete Trace between a Honest Agent and an Attacker which violates security properties.| <!-- Does that mean that there is no attack trace assuming a protocol is badly broken and entities fail to achieve authentication even without any attacker? Why not "concrete trace that violates a security property?" -->
|Abstract Trace|Process which describes interactions between Agents and allows to derive multiple concrete traces.| <!--OK for a glossary, but this will need a proper definition. However, I don't quite see why an abstract trace can yield more than one concrete traces (assuming random generators are made deterministic for the purpose of fuzzing).-->
