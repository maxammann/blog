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
|Sane Message|A TLS message which is parsable.|
|Agent|An entity which runs a TLS client or server|
|Honest Agent|Agent which aims to follow the TLS spec and avoid security violations.|
|Dishonest Agent|Agent which does not follow the TLS spec but sends Sane Messages|
|Attacker|A dishonest Agent which aims to violate security properties of other Honest Agents|
|Concrete Trace|Sequence of Sane Messages between Agents. They are concrete in the sense that each execution yields the exact same behavior, under the assumption that the PUT is deterministic.|
|Happy Trace|Concrete Trace between two Honest Agents which does not violate security properties|
|Attack Trace|Concrete Trace between a Honest Agent and an Attacker which violates security properties.|
|Abstract Trace|Process which describes interactions between Agents and allows to derive multiple concrete traces.|
