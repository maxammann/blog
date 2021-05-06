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

In this post we try to model what an attacker can compute and therefore which attacks tlspuffin should be able to detect and report. Everything message, which an attacker can deduce from its knowledge should be the input space of the fuzzer.

Before we can define the capabilities of the attacker more closely, we need to define some concepts.

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

What we are missing is atomic data to which the functions can be applied to. When modeling security protocols, you typically use the concept of *names* $\mathcal{N} = \\{n, r, s, ...\\}$. Names can be nonces, random data, session identifiers or keys. There are different subsets of names through, which both have infinitely many names to model the possibility of attackers to choose random values.
$\mathcal{N}\_{pub}$ contains names which are public and available to the attacker e.g. a session identifier like an IP address. 
$\mathcal{N}\_{prv}$ includes private keys of protocol participants. These are usually hidden within the implementations of participants. 

The separation between public and private names is necassary as like in reality data can be private or publicly known in the network. Private names can become known to the attacker by observing it on the network. This gain of knowledge is modeled through a frame, which is introduced later on.

The set of all terms $\mathcal{T}(F,N)$ over the set of functions $F$ and atoms $N$ is defined as: 

{{< katex >}}
\begin{alignat*}{3}
t,t_1,... :=    \quad& n            \qquad &\,n \in N \\
                & f(t_1,...,t_k)    \qquad &\,f \in F, \text{arity}(f) = k
\end{alignat*}
{{< /katex >}}

If we limit the allowed atoms and functions to $\mathcal{F}$ and $\mathcal{N}$ respectively, then we get the set of all closed terms $\mathcal{T}(\mathcal{F}, \mathcal{N})$. We also call these terms grounded terms.


There are a few helper functions where are defined on terms.
$vars(t)$ describes the set of variables used in the term $t$ and is defined as:

{{< katex >}}
\begin{alignat*}{3}
&vars(t) = vars(f(t_1,...,f_n)) = \bigcup_{i=1}^{n} vars(t_i) &\quad\text{if $t$ is a function}\\
&vars(t) = \{t\} &\quad\text{if } t \in \mathcal{X}\\
&vars(t) = \emptyset
\end{alignat*}
{{< /katex >}}


$st(t)$ describes the set of all sub-terms of the term $t$. An example:

{{< katex >}}
\begin{equation*}
st(\text{sdec}(\text{senc}(\text{h}(x), y), y)) = \{y, x, \text{h}(x), \text{senc}(\text{h}(x), y), \text{sdec}(\text{senc}(\text{h}(x), y), y)\}
\end{equation*}
{{< /katex >}}
### Substitution

In order to manipulate terms and transform them we need to introduce the concept of substitution. For that reason we introduce the set of variables $\mathcal{X} = \\{a, b, c, ...\\}$. Variables are holes in terms which can be filled by other terms. Therefore, a substitution $\sigma$ maps recipe terms $t \in \mathcal{T}(\mathcal{F}, \mathcal{N}_{pub} \cup dom(\sigma))$ to grounded terms $\tilde{t} \in \mathcal{T}(\mathcal{F}, \mathcal{N}$ by filling the variables (or holes). Usually one writes postfix $t\sigma$ instead of $\sigma(t)$ to apply the substitution $\sigma = \\{a \mapsto b, c \mapsto t_2, ...\\}$. We define the domain of the substitution as $dom(\sigma) = \\{a, b, c, ...\\} \subseteq \mathcal{X}$. Formally substitution is defined as follows:

{{< katex >}}
\begin{alignat*}{3}
&t\sigma = f(t_1,...,f_n)\sigma = f(t_1\sigma),...,t_n\sigma))&\quad\text{if $t$ is a function}\\
&t\sigma = t\sigma &\quad\text{if } t \in dom(\sigma)\\
&t\sigma = t
\end{alignat*}
{{< /katex >}}

This means, if we encounter a term which is a function, then we apply the substitution on all arguments. If the term is in $dom(\sigma)$, then we can replace it with the corresponding term in the substitution. If the term is not a function and is not in the domain of $\sigma$, then we do nothing and omit $\sigma$.
## Fuzzing Input Space

The fuzzer will be able to use the available function symbols $\mathcal{F}$, names $\mathcal{N}$ and learned knowledge to construct arbitrary terms. Indeed, this is the input space of the fuzzer. The semantics of the functions and public names is given by concrete implementations in the fuzzer.

Even though, the fuzzer does not need formal definitions for the semantics of symbols, we still want to provide them here. One might ask why this overhead is beneficial? As already mentioned previously the fuzzer users a bug oracle to decide whether a specific execution of a trace violates a security policy. 

One way to implement a security policy is to look at the obtained knowledge of the attacker during the execution. If the attacker knows $k$ and also witnessed $\text{senc}(x, k)$, then he also knows $x$ even though he never directly observed $x$. If $x \in \mathcal{N}_{prv}$ then we maybe found a security violation. This problem is also known as the *deduction problem*. The problem can be solved by providing a decision procedure which can decide $S \vdash x$, which means whether the term $x$ is deducible from the set $S=\\{\text{senc}(x, k), k\\}$. Note that this problem is in general Turing-complete, but one can restrict the underlying formal model to achieve decidability [^1]. This allows the bug oracle to decide over secrecy. **In practice this is difficult to implement, because we need to know the term structure which is output by the implementations.**

Another way to implement a security policy is to record events over the execution of the trace. These events are also known as claims. For example if we can make the server believe that a client is authenticated, and the client did not claim that it is already authenticated, then we would have an authentication violation. A real-world example for this kind of vulnerability in TLS is the SKIP bug. In a nutshell this vulnerability allows a client attacker with a certificate, but without the private key, to impersonate other clients. The attacker can make the TLS server believe that it has the private key by skipping a message in the TLS protocol.


In conclusion, the fuzzer could have two different ways of expressing semantics for function symbols:
* Semantics via a concrete implementations
* Semantics via a formal model to decide deducibility

The first way can be achieved by defining a term rewriting system which provides a formal way of transforming terms.

Before we take a look at term rewrite systems as a formal model for deducibility we quickly take a look at inference systems which model what an attacker needs to do to reduce a message from an operational point of view.
## Inference Systems

TODO: Def

Inference systems

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

# Deduction in Inference Systems

TODO

### Why are Inference Systems not enough?

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


## Term Rewriting System

A term rewriting system $R$ is a finite relation on terms. A rewrite rule is a pair $(\ell, r) \in R$ and can be written as $\ell \rightarrow r$, where $\ell \in \mathcal{T}(\mathcal{F}, \mathcal{X})$ and $r \in \mathcal{T}(\mathcal{F_c}, vars(\mathcal{\ell}))$. Classically, there are two restrictions on rewrite rules as already defined[^3]:
* the left side $l$ is not a variable and contains at least one function symbol.
* $r \in \mathcal{T}(\mathcal{F}, vars(\ell))$, which means that each variable which appears on the right-hand side also appears on the left-hand side.
* Function symbols on the right-hand side are constructors instead of destructors. Usually we do not want as a rewrite rule like $\text{pair}(x, y) \rightarrow \text{proj}_2(pair(x, y))$ would make the rewrite system infinite.


## Equational Theories

TODO Def. of EQ-T

{{< katex >}}
\begin{alignat*}{2}
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

## Deducibility for EQ and TRS

TODO
## Modeling the Attacker

In our case a single attacker which has full control over the network is enough to model every possible attack for a TLS client and server setup. This is easy to see as a single attacker can act as multiple attackers. Therefore, the capabilities of a single attacker and multiple attackers coincide.

Every message which is sent by and network participant is witnessed the attacker. The attacker can forward the message to the intended recipient, modify it or just drop and ignore it. Cheval et. al conclude conclude that in such a case the attacker has the following capabilities:
* eavesdropping messages and gain knowledge,
* deduct further terms from messages, like gaining access to a secret if the attacker eavesdropped on the cipher-text and the corresponding key to decrypt it, and
* control messages as the attacker can CRUD messages them and forward them to specific network participants.

Abadi and Fournet describe the notion of processes to model security protocols using the applied pi calculus [^4]. Process specifications of protocols allows making statements about security properties like secrecy or authentication. We want to use the ideas of processes and define a notion of more concrete executions of the protocols. A process defines all possible executions of a protocol, which is important to prove certain properties.

In our case we do not want to prove that a specification fulfills certain properties, but want fuzz-test implementations. We try to bridge the gab between formal verification and manual testing with fuzzing. Protocols, as defined in the applied pi calculus, do not have the concept of black-box implementations. The process definitions more or less describes the implementation of a higher level and does not use concrete implementations but more abstract semantics for functions. Therefore, we are not looking for a way to define processes, but more concrete and specific executions of a protocol which we call a *trace*. To make this difference more clear see the following example of ProVerif syntax which describes a TLS 1.3 client process:


```kotlin
new cr:random;
let (x:bitstring,gx:element) = dh_keygen() in
let (early_secret:bitstring,kb:mac_key) = kdf_es(psk) in
let offer = ...
out(io, CH(cr,offer));
```

As you can see the process models the internal behavior of the TLS 1.3. While this is essential to prove authentication or secrecy, we do not want to formally define how TLS work. We expect that the implementation follows it and want to execute it to determine whether security violations happened or not. 


The following definition of traces captures the essence of the interaction between network participants which use black-box implementations.


## Traces

Firstly, we want to extend our notion of variables to handles $\mathcal{X} = \mathcal{H} \cup \mathcal{X}$. Handles are just like regular variables but are used as references to actual terms which the attacker learned. The knowledge is also known the frame $\Phi$, which will be introduced in the next section about extended traces.

Traces model interactions between multiple network participants in the presence of an attacker. Participants need to have a name. We model these names through session identifiers $\mathcal{S} \subseteq \mathcal{N}_{pub}$. The infinite set $\mathcal{S}$ contains all session identifiers. This participants just exist and can be referenced. They do not need to be spawned beforehand.

A trace is defined as follows:

{{< katex >}}
\begin{align*}
T, R := && 0                \qquad&&\text{null} \\
        && \bar{u}(h_n).T   \qquad&&\text{send} \\
        && u(t).T           \qquad&&\text{receive}
\end{align*}
{{< /katex >}}

where the handle $h_n \in \mathcal{H}$, the handle index $n \in \mathbb{N}$, $t\ \in \mathcal{T}(\mathcal{F}, N_{pub} \cup \mathcal{H})$ is a term and $u \in \mathcal{S}$. Actions can be concatenated using a $.$ to create a trace which does several things e.g. $\bar{c}(h_1).\text{s}(t_1).\bar{s}(h_2)$.

### Extended Traces

The set of opaque and abstract states of internal implementation is called $State$. Each $st \in State$ contains the internal states of all network participants. For example at some point in time the state $st \in State$ contains the shared key between a client $c \in \mathcal{S}$ and a server $s \in \mathcal{S}$.

We already mentioned the attacker knowledge already. The attacker knowledge is modeled through a substitution $\Phi$ and is also known as a frame. We gradually extend this frame during the execution of a trace.

TODO: def Msg

Based on this we define the triple $A = (T, st, \Phi)$ as an extended trace:

* $T$ is a closed plain trace
* $st \in State$ is an opaque state which resembles the internal states of all sessions
* $\Phi = \\{ h_1 \mapsto t_1, ..., h_n \mapsto t_n \\}$, called the frame is a substitution from handles to ground constructor terms


TODO: Events: Crash Events Include events/claims in model

TODO: Rule, Session ids, identity differenciation

### Semantics of Extended Traces

{{< katex >}}

\begin{align}
(\bar{u}(h_n).T, st, \Phi) 
\xrightarrow{\bar {\xi}(h_n)} 
(
    T, 
    \tilde{st},
    \Phi \cup \{h_n \mapsto out(\tilde{st}, \xi), \}
) \\
\text{where $\tilde{st} = next(st, \xi, \sigma)$} \\
\text{if $\xi \in \mathcal{S}$ and $Msg(out(\tilde{st}, \xi))$}
\tag{SEND}
\end{align}


\begin{align}
(u(t).T, st, \Phi) 
\xrightarrow{\xi(\zeta)} 
(
    T, 
    next(st, \xi, t\Phi\downarrow),
    \Phi
) \\
\text{if $\xi \in \mathcal{S}$, the recipe $t \in \mathcal{T}(\mathcal{F}, N_{pub} \cup \mathcal{H})$ and $Msg(t\Phi)$}
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
out: State \times N_{pub} \rightarrow \mathcal{T}(\mathcal{F}, \mathcal{N})
\end{equation*}
{{< /katex >}}


## Example

{{< katex >}}
$$
T:=\bar{c}(h_1).\text{s}(t_1).\bar{s}(h_2)
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
\omega := \text{CH}(\text{s}(h_1), \text{r}(h_1), \emptyset, \text{co}(h_1), \text{ci}(h_1))
$$
{{< /katex >}}

{{< resourceFigure "syntax.drawio.svg" >}}
Definition of the syntax in the example below. Each state $st \in State$ is visualized by the rounded square. The first line shows the trace until which step it is executed. The second line references the current state, and the last one includes the knowledge of the attacker denoted by the frame $\Phi$.
 {{< /resourceFigure >}}

{{< resourceFigure "example.drawio.svg" >}}
Example execution of a trace.
 {{< /resourceFigure >}}



[^1]: Blanchet, Bruno, Ben Smyth, Vincent Cheval, and Marc Sylvestre. 2020. ProVerif 2.02pl1: Automatic Cryptographic Protocol Verifier, User Manual and Tutorial.
[^2]: Baader, Franz, and Tobias Nipkow. 1998. Term Rewriting and All That. 1st ed. Cambridge University Press. https://doi.org/10.1017/CBO9781139172752.
[^3]: Bezem, M., J. W. Klop, Roel de Vrijer, and Terese (Group), eds. 2003. Term Rewriting Systems. Cambridge Tracts in Theoretical Computer Science, v. 55. Cambridge, UK ; New York: Cambridge University Press.
[^4]: Abadi, Martı́n, and Cédric Fournet. 2001. “Mobile Values, New Names, and Secure Communication.” In Proceedings of the 28th ACM SIGPLAN-SIGACT Symposium on Principles of Programming Languages - POPL 01. ACM Press. https://doi.org/10.1145/360204.360213.