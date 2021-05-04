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

In this post we try to model what an attacker can compute. Everything which an attacker can deduce from its knowledge should be the input space of the fuzzer. That way we can be sure that all attacks which are possible are indeed fuzzed.

Before we can define what an attacker can deduce from received messages we need to define some concepts.

## Term Algebra

We will model the messages of the TLS protocol as terms. This is a common practice when modeling security protocols. Cryptographic operations are modeled by *functions* of fixed arity $\mathcal{F}=\\{f\/n,g\/m,...\\}$. The arity $k$ of a function $f$ is defined as $\text{arity}(f)=k$.
The set of all functions contains both *constructors* $\mathcal{F}_c$ and *destructors* $\mathcal{F}_d$. Examples for constructors are encryption, signatures and hashes. Destructors can fail based on the data structure they operate on. A destructor can for example extract known fields out of a known TLS message. Function symbols with an arity of $0$ are called *constants*.

{{< katex >}}
\begin{align*}
\mathcal{F}_c &= \{\text{senc}/2, \text{aenc}/2, pk/1, \text{h}/1, 0/0, \text{TLS\_AES\_256\_GCM\_SHA384}/0\} \\
\mathcal{F}_d &= \{\text{sdec}/2, \text{adec}/2 \}
\end{align*}
{{< /katex >}}

The above finite set of function symbols is also called a *signature*. This *signature* contains functions to encrypt and decrypt terms and also contains the constants $0$ and $\text{TLS\\_AES\\_256\\_GCM\\_SHA384}$ which is a cipher of TLS 1.3.

What we are missing is atomic data to which the functions can be applied to. When modeling security protocols, you typically use the concept of *names* $\mathcal{N} = \\{n, r, s, ...\\}$. Names can be nonces, random data, session identifiers or keys. There are different subsets of names through, which both have infinitely many names to model the possibility of attackers to choose random values. $\mathcal{N}\_{pub}$ contains names which are public and available to the attacker e.g. a session identifier like an IP address. $\mathcal{N}\_{prv}$ includes private keys of protocol participants. These are usually hidden within the implementations of participants. The separation between public and private names is necassary as like in reality data can be private or publicly known in the network. Private names can become known to the attacker by observing it on the network. This gain of knowledge is modeled through a frame, which is introduced later on.

The set of all terms $\mathcal{T}(F,N)$ over the set of functions $F$ and atoms $N$ is defined as: 

{{< katex >}}
\begin{alignat*}{3}
t,t_1,... :=    \quad& n            \qquad &\,n \in N \\
                & f(t_1,...,t_k)    \qquad &\,f \in F, \text{arity}(f) = k
\end{alignat*}
{{< /katex >}}

If we limit the allowed atoms and functions to $\mathcal{F}$ and $\mathcal{N}$ respectively, then we get the set of all closed terms $\mathcal{T}(\mathcal{F}, \mathcal{N})$. We also call these terms grounded terms.

In order to manipulate terms and transform them we need to introduce the concept of substitution. For that reason we introduce the set of axioms $\mathcal{AX} = \\{ax_1, ax_2, ax_3, ...\\}$. Axioms are in fact just variables. They are holes in terms which can be filled by other terms. Therefore, a substitution $\sigma$ maps terms to terms by filling the variables (or holes). Usually one writes postfix $t\sigma$ instead of $\sigma(t)$ to apply the substitution $\sigma = \\{ax_1 \mapsto t_1, ax_2 \mapsto t_2, ..., ax_n\\}$. If $t \in dom(\sigma) = \\{ax_1, ax_2, ..., ax_n\\} \subseteq \mathcal{AX}$ then we use the prefix notation like in the following definition:

{{< katex >}}
\begin{alignat*}{3}
f(t_1,...,f_n)\sigma = f(t_1\sigma),...,t_n\sigma))&\quad\text{if $t$ is a function}\\
t\sigma = \sigma(t) &\quad\text{if } t \in dom(\sigma) \\
t\sigma = t &\quad\text{if }
\end{alignat*}
{{< /katex >}}

This means, if we encounter a term which is a function, then we apply the substitution on all arguments. If the term is in $dom(\sigma)$, then we can replace it with the corresponding term in the substitution. If the term is not a function and is not in the domain of $\sigma$, then we do nothing. 


Our goal is to define an input space for the fuzzer. The fuzzer will be able to use the available function symbols of $\mathcal{F}$, but how do they behave? This is an important question as the fuzzer should know as soon as it has witnessed a private name from $\mathcal{N_prv}$. In order to give the fuzzer this ability it needs to know what an encryption, calculation a hash means.

A term rewriting system $R \subseteq \mathcal{T}(\mathcal{F}, \mathcal{AX})$ is a finite relation on terms. A rewrite rule is a pair $(l, r) \in R$ and can be written as $l \rightarrow r$. There are two restrictions on these rules[^3]:
* the left side $l$ is not a variable
* $r \in \mathcal{T}(\mathcal{F}, vars(l))$, which means that each variable which appears on the right-hand side also appears on the left-hand side.

TODO: subterm, destructor,

Furthermore, one may note, that the rewriting system $R$ defines the spaces of terms which the attacker can compute, which is infinite. For example if the attacker knows the term $\text{aenc}(m, pk(k))$ and $k$, she can use the recipe $\xi=\text{adec}(ax_1, ax_2)$ to compute the term $m$, where $ax_1$ and $ax_2$ are handles to the messages already received.



TODO Convergent Term Rewriting Systems

* A convergent theory is an equational theory induced by a convergent rewriting
system. The theory is sub-term convergent if there is a corresponding (convergent) rewriting system such that any rewrite rule $\mathcal{l} \rightarrow \mathcal{r}$ is such that $\mathcal{r}$ is a subterm of $\mathcal{l}$[^1].
* If $R$ is a finite convergent TRS, $=_E$ is decidable: $s=_Et \Leftrightarrow s\downarrow=_Et\downarrow$ [^2]

## Inference Systems

TODO Def. of EQ-T

A simple example for an inference system $I_{ENC}$ looks like this:

{{< katex >}}
\begin{alignat*}{2}
{\text{senc}(x,y) \quad y \over x}                      &\qquad
{x \quad y \over \text{senc}(x,y)}                      \\
{\text{aenc}(x,pk(y)) \quad y \over x}                  &\qquad
{x \quad y \over \text{aenc}(x,y)}                      \\
\end{alignat*}
{{< /katex >}}

This models (a)symmetric encryption and decryption. If an attacker has the symmetrically encrypted plain text and $y$, then he is able to deduce $x$. 

## Deduction

## Why are Inference Systems not Enough?

An inference system is not able easily model all cryptographic primitives like modular exponentiation or exclusive or[^1].

Naively, one might think that in case of exponentiation, a rule of the inference system could look like this:

{{< katex >}}
$$
{\text{exp}(\text{exp}(x, y), z) \over \text{exp}(\text{exp}(x, z), y)}
$$
{{< /katex >}}

Actually, we have a problem with this. Not only that it is no longer finite, but we are still not able to properly deduce terms. Let's say we want to proof that the following is true. Indeed, it should be true as we just exchanged exponents in the precondition, which should be valid for exponentiation. At least that is what we try to model.

{{< katex >}}
$$
\{\text{exp}(\text{exp}(\text{exp}(g, c), b), a)\}\vdash_{I_{EXP}} \text{exp}(\text{exp}(\text{exp}(g, a), c), b)
$$
{{< /katex >}}

Now lets try to deduce this:

{{< katex >}}
$$
{\text{exp}(\text{exp}(\text{exp}(g, c), b), a) \over \text{exp}(\text{exp}(\text{exp}(g, c), a), b)}
$$
{{< /katex >}}

After applying the first rule, we see that we will never be able to move the $a$ within the most-inner function. We could introduce now a new rule for it, but what if we have 4, 5 or 6 nested exponentiations? Indeed, we would need infinitely many rules in our inference system to model this.

A solution for this problem are **equational theories**.

## Equational Theories

TODO Def. of EQ-T

{{< katex >}}
\begin{alignat*}{2}
\text{CH}(\text{s}(t), \text{r}(t), \text{ex}(t), \text{co}(t), \text{ci}(t)) &= t &\quad
\text{SH}(\text{s}(t), \text{r}(t), \text{ex}(t), \text{co}(t)) &= t \\
\text{exp}(\text{exp}(x, y), z) &= \text{exp}(\text{exp}(x, z), y)  &\quad
\\
\text{sdec}(\text{senc}(x, y), y)&=x &\quad
\text{adec}(\text{aenc}(x, pk(y)), y)&=x \\

\text{xor}(x, xo\text{r}(y, z))&=xo\text{r}(xo\text{r}(x, y), z)                                &\quad
\text{xor}(x, y)&=xo\text{r}(y, x)                                                \\
\text{xor}(x, x)&=0                                                        &\quad
\text{xor}(x, 0)&=x                                                        \\
\end{alignat*}
{{< /katex >}}
## Traces

A trace is defined as follows:

{{< katex >}}
\begin{align*}
T, R := && 0                \qquad&&\text{null} \\
        && \bar{u}(ax_n).T  \qquad&& \text{send} \\
        && u(t).T           \qquad&&\text{receive}
\end{align*}
{{< /katex >}}

, where the handle $ax_n \in \mathcal{AX}$, the handle index $n \in \mathbb{N}$, $t\ \in \mathcal{T}(\mathcal{F}, N_{pub} \cup \mathcal{AX})$ is a term and $u \in N_{pub}$. Actions can be concatenated using a $.$ to create a trace which does several things e.g. $\bar{c}(ax_1).\text{s}(t_1).\bar{s}(ax_2)$.

### Extended Traces

An extended trace is a pair $A = (T, st, \Phi)$

* $T$ is a closed plain trace
* $st \in State$ is an opaque state which resembles the internal states of all sessions
* $\Phi = \\{ ax_1 \mapsto t_1, ..., ax_n \mapsto t_n \\}$, called the frame is a substitution from axioms to ground constructor terms

TODO Def frame

TODO Def State
* The set of opaque states $State$. Each state contains the internal states of all agents. For example at some point in time the state $st \in State$ contains the shared key between a client $c \in N_{pub}$ and a server $s  \in N_{pub}$.

TODO Def axioms
* The set of all axioms which represent handles to messages $\mathcal{AX} = \\{ax_n | n \in \mathbb{N} \\}$. Not all message handles are used.



### Semantics of Extended Traces

{{< katex >}}

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

#### Black-box

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


## Example

{{< katex >}}
$$
T:=\bar{c}(ax_1).\text{s}(t_1).\bar{s}(ax_2)
$$
$$
\{c,s\} \subseteq N_{pub}
$$
$$
State=\{s_1, s_2, s_3\}
$$
$$
\mathcal{F}_c=\{CH/5\}\\
\mathcal{F}_d=\{s/1, r/1, ex/1, co/1, ci/1\}\\
\mathcal{F}=\mathcal{F}_c \cup \mathcal{F}_d
$$
{{< /katex >}}

Rewriting System $R$:

{{< katex >}}
$$
\text{CH}(\text{s}(t), \text{r}(t), \text{ex}(t), \text{co}(t), \text{ci}(t)) = t \\

\text{s}(\text{CH}(x, y, z, d, e)) = x\\
\text{r}(\text{CH}(x, y, z, d, e)) = y\\
\text{ex}(\text{CH}(x, y, z, d, e)) = z\\
\text{co}(\text{CH}(x, y, z, d, e)) = d\\
\text{ci}(\text{CH}(x, y, z, d, e)) = e
$$
{{< /katex >}}


Attacker recipe:

{{< katex >}}
$$
\omega := \text{CH}(\text{s}(ax_1), \text{r}(ax_1), \emptyset, \text{co}(ax_1), \text{ci}(ax_1))
$$
{{< /katex >}}

{{< resourceFigure "graph.drawio.svg" >}}

 {{< /resourceFigure >}}



[^1]: [Formal Models and Techniques for Analyzing SecurityProtocols: A Tutorial](https://hal.inria.fr/hal-01090874/document)
[^2]: Franz Baader, Tobias Nipkow. Term rewriting and all that.Cambridge University Press (1998)
[^3]: Terese. Term Rewriting Systems-Cambridge University Press (2003)