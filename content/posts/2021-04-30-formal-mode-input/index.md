---
layout: post
title: "tlspuffin: Formal Model of Input Space"
date: 2021-04-24
slug: tlspuffin-formal-model
draft: false

katex: true
hypothesis: true

keywords: []
categories: [research-blog]
---



## Syntax

* Cryptographic operations are modeled by symbols of fixed arity $F=\\{f\/n,g\/m,...\\}$. $F$ contains both constructors $F_c$ and destructors $F_d$.
* $N_{pub}$ contains all publicly known names. Usually this set contains only the session identifiers of the participating agents. Therefore, the public set of names could contain the session identifiers for a client $c$ and a server $s$ modeled as symbol names.
* The rewriting systemd $R$ defines the spaces of terms which the attacker can compute. For example if the attacker knows the term $aenc(m, pk(k))$ and $k$, she can use the recipe $\Xi=adec(ax_1, ax_2)$ to compute $m$, where $ax_1$ and $ax_2$ are handles to the messages already received.
* The set of opaque states $State$. Each state contains the internal states of all agents. For example at some point in time the state $st \in State$ contains the shared key between a client $c \in N_{pub}$ and a server $s  \in N_{pub}$.
* The set of all axioms which represent handles to messages $\mathcal{AX} = \\{ax_n | n \in \mathbb{N} \\}$. Not all message handles are used.
* The set of all terms is described by $\mathcal{T}(\mathcal{F}, N_{pub} \cup \mathcal{AX} \cup dom(\Phi))$.
<!--
* A rewriting system is usually not enough when the protocol contains terms like $g^{ab}$ as there is no way to know that it is equal to $g^{ba}$. As this kind of computation is important in DH, the attack should be able to reason about it.
-->

### Rewriting Systems

In this post we try to model what an attacker can compute. Everything which an attacker can deduce from its knowledge should be the input space of the fuzzer. That way we can be sure that all attacks which are possible are indeed fuzzed. Classically, this is also called an inference system. A rule in a inference system looks like this:

$$
{\text{senc}(x,y) \quad y \over x}
$$

This means if an attacker has the cipher text and $y$ then he is able to deduce $x$. This is sufficient to model symmetric and asymmetric encryption. An inference system is not able to model modular expansion [^1].

$$
{\text{exp}(\text{exp}(x, y), z) \over \text{exp}(\text{exp}(x, z), y)}
$$


{{< katex >}}
\begin{alignat*}{2}
\text{CH}(s(t), r(t), ex(t), co(t), ci(t)) &= t                     &\quad 
\text{SH}(s(t), r(t), ex(t), co(t)) &= t                            \\
\text{exp}(\text{exp}(x, y), z) &= \text{exp}(\text{exp}(x, z), y)  &\quad 
                                                                    \\
\text{sdec}(\text{senc}(x, y), y)&=x                                &\quad
\text{adec}(\text{aenc}(x, pk(y)), y)&=x                            \\
xor(x, xor(y, z))&=xor(xor(x, y), z)                                &\quad
xor(x, y)&=xor(y, x)                                                \\
xor(x, x)&=0                                                        &\quad
xor(x, 0)&=x                                                        \\
\end{alignat*}
{{< /katex >}}

### Trace

A trace is defined as follows:

{{< katex >}}
\begin{align*}
T, R := && 0                \qquad&&\text{null} \\
        && \bar{u}(ax_n).T  \qquad&& \text{send} \\
        && u(t).T           \qquad&&\text{receive}
\end{align*}
{{< /katex >}}

where the handle $ax_n \in \mathcal{AX}$, the handle id $n \in \mathbb{N}$, $t\$ is a term and $u \in N_{pub}$. Actions can be concatenated using a $.$ to create a trace which does several things e.g. $\bar{c}(ax_1).s(t_1).\bar{s}(ax_2)$.

### Extended Trace

An extended trace is a pair $A = (T, st, \Phi)$

* $T$ is a closed plain trace
* $st \in State$ is an opaque state which resembles the internal states of all sessions
* $\Phi = \\{ ax_1 \mapsto t_1, ..., ax_n \mapsto t_n \\}$, called the frame is a substitution from axioms to ground constructor terms

## Semantics

{{< katex >}}
\begin{align}
(0.T, st, \Phi) 
\xrightarrow{\epsilon} 
(T, st, \Phi)
\tag{NULL}
\end{align}


\begin{align}
(\bar{u}(ax_n).T, st, \Phi) 
\xrightarrow{\bar {\xi}(ax_n)} 
(
    T, 
    \tilde{st},
    \Phi \cup \{ax_n \mapsto out(\tilde{st}, \xi), \}
) \\
\text{where $\tilde{st} = next(st, \xi, \sigma)$} \\
\text{if $\xi \in N_{pub}$ and $Msg(out(\tilde{st}, \xi))$}
\tag{SEND}
\end{align}


\begin{align}
(u(t).T, st, \Phi) 
\xrightarrow{\xi(\zeta)} 
(
    T, 
    next(st, \xi, t\Phi),
    \Phi
) \\
\text{if $\xi \in N_{pub}$, the recipe $t \in \mathcal{T}(\mathcal{F}, N_{pub} \cup \mathcal{AX})$ and $Msg(t\Phi)$}
\tag{REC}
\end{align}

{{< /katex >}}

### Black-box

We use two black-box functions in our semantics. The first one maps an opaque state, a session name, and a term to a new state. If there is no term to input then a $\sigma$ is used to drive the black-box forward without inputting anything.

{{< katex >}}
\begin{equation*}
next: State \times N_{pub} \times \mathcal{T}(\mathcal{F}, N_{pub} \cup dom(\Phi) \cup \{\sigma\}) \rightarrow State
\end{equation*}
{{< /katex >}}

The other function gets a single term from a session referenced by a session name in the current state:

{{< katex >}}
\begin{equation*}
out: State \times N_{pub} \rightarrow \mathcal{T}(\mathcal{F}, N_{pub} \cup dom(\Phi))
\end{equation*}
{{< /katex >}}


### Example

{{< katex >}}
$$
T:=\bar{c}(ax_1).s(t_1).\bar{s}(ax_2)
$$
$$
N_{pub}=\{c,s\}
$$
$$
State=\{s_1, s_2, s_3\}
$$
$$
F_c=\{CH\backslash5\}\\
F_d=\{s\backslash1, r\backslash1, ex\backslash1, co\backslash1, ci\backslash1\}\\
F=F_c \cup F_d
$$
{{< /katex >}}

Rewriting System $R$:

{{< katex >}}
$$
CH(s(t), r(t), ex(t), co(t), ci(t)) = t

s(CH(x, y, z, d, e)) = x\\
r(CH(x, y, z, d, e)) = y\\
ex(CH(x, y, z, d, e)) = z\\
co(CH(x, y, z, d, e)) = d\\
ci(CH(x, y, z, d, e)) = e
$$
{{< /katex >}}


Terms for abbreviations:

{{< katex >}}
$$
\Xi := CH(s(ax_1), r(ax_1), \emptyset, co(ax_1), ci(ax_1))
$$
{{< /katex >}}

{{< resourceFigure "graph.drawio.svg" >}}

 {{< /resourceFigure >}}



[^1]: [Formal Models and Techniques for Analyzing SecurityProtocols: A Tutorial](https://hal.inria.fr/hal-01090874/document)