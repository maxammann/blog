---
layout: post
title: "tlspuffin: Formal Model of Input Space"
date: 2021-04-24
slug: tlspuffin-formal-model
draft: false

katex: true

keywords: []
categories: [research-blog]
---

## Syntax


## Rewriting Systems

## Equivalence System

### Symbols

TODO

* N_pub
* State
* Axioms
* N_priv?
* F_c, F_d, F
* Rewriting System R

### Trace

A trace is defined as follows:

{{< katex >}}
\begin{align*}
T, R := && 0                \qquad&&\text{null} \\
        && \bar{u}(ax_n)    \qquad&& \text{send} \\
        && u(t)             \qquad&&\text{receive}
\end{align*}
{{< /katex >}}

where the handle $ax_n \in \mathcal{AX}$, the handle id $n \in \mathbb{N}$, $t\$ is a term and $u \in N_{pub}$.

### Extended Trace

An extended process is a pair $A = (\varUpsilon, \Phi, st)$

* $\varUpsilon$ is a multiset of closed plain traces
* $\Phi = \\{ ax_1 \mapsto t_1, ..., ax_n \mapsto t_n \\}$, called the frame is a substitution from axioms to ground constructor terms
* $st \in State$ is an opaque state which resembles the internal states of all sessions

## Semantics



{{< katex >}}
\begin{align}
(\varUpsilon \cup \{\!\!\{0\}\!\!\}, \Phi, st) 
\xrightarrow{\epsilon} 
(\varUpsilon, \Phi, st)
\tag{NULL}
\end{align}


\begin{align}
(\varUpsilon \cup \{\!\!\{\bar{u}(ax_n).T\}\!\!\}, \Phi, st) 
\xrightarrow{\bar {\xi}(ax_n)} 
(
    \varUpsilon \cup \{\!\!\{T\}\!\!\}, 
    \Phi \cup \{ax_n \mapsto out(\tilde{st}, \xi), \}, 
    \tilde{st}
) \\
\text{where $\tilde{st} = next(st, \xi, \sigma)$} \\
\text{if $\xi \in N_{pub}$ and $Msg(out(\tilde{st}, \xi)$}
\tag{SEND}
\end{align}


\begin{align}
(\varUpsilon \cup \{\!\!\{u(t).T\}\!\!\}, \Phi, st) 
\xrightarrow{\xi(\zeta)} 
(
    \varUpsilon \cup \{\!\!\{T\}\!\!\}, 
    \Phi, 
    next(st, \xi, t)
) \\
\text{if $\xi \in N_{pub}$ and $t \in \mathcal{T}(\mathcal{F}, N_{pub} \cup \mathcal{AX} \cup dom(\Phi))$}
\tag{REC}
\end{align}

{{< /katex >}}

### Black-box

We use two black-box functions in our semantics. The first one maps an opaque state, a session name, and a term to a new state. If there is no term to input then a $\sigma$ is used to drive the black-box forward without inputting anything.

{{< katex >}}
\begin{equation*}
next: State \times N_{pub} \times \mathcal{T}(\mathcal{F}, N_{pub} \cup \mathcal{AX} \cup dom(\Phi) \cup \{\sigma\}) \rightarrow State
\end{equation*}
{{< /katex >}}

The other function gets a single term from a session referenced by a session name in the current state:

{{< katex >}}
\begin{equation*}
out: State \times N_{pub} \rightarrow \mathcal{T}(\mathcal{F}, N_{pub} \cup \mathcal{AX} \cup dom(\Phi))
\end{equation*}
{{< /katex >}}


### Example


{{< resourceFigure "graph.drawio.svg" >}}

 {{< /resourceFigure >}}
