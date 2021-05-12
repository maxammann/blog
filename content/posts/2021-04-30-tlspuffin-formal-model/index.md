---
layout: post
title: "tlspuffin: Formal Model"
date: 2021-04-24
slug: tlspuffin-formal-model
draft: false

katex: true
hypothesis: true

keywords: []
categories: [research-blog]
---

My symbolic-model guided fuzzer for OpenSSL has now a name. It is called `tlspuffin` and stands for **T**LS **P**rotocols **U**nder **F**uzz**IN**g.

In this post we try to model what an attacker can compute and therefore which attacks tlspuffin should be able to detect and report. Everything message, which an attacker can deduce from its knowledge should be the input space of the fuzzer.

Before we can define the capabilities of the attacker more closely, we need to define some concepts.

## Term Algebra

We will model the messages of the TLS protocol as terms. This is a common practice when modeling security protocols. Cryptographic operations are modeled by *functions* of fixed arity $\mathcal{F}=\\{f\/n,g\/m,\dots\\}$. The arity $k$ of a function $f$ is defined as $\text{arity}(f)=k$.
The set of all functions contains both *constructors* $\mathcal{F}_c$ and *destructors* $\mathcal{F}_d$. Examples for constructors are encryption, signatures and hashes. Destructors can fail based on the data structure they operate on. A destructor can for example extract known fields out of a known TLS message. Function symbols with an arity of $0$ are called *constants*.

{{< katex >}}
\begin{align*}
\mathcal{F}_c &= \{\text{senc}/2, \text{aenc}/2, pk/1, \text{h}/1, 0/0, \text{TLS\_AES\_256\_GCM\_SHA384}/0\} \\
\mathcal{F}_d &= \{\text{sdec}/2, \text{adec}/2 \}
\end{align*}
{{< /katex >}}

The above finite set of function symbols is also called a *signature*. This *signature* contains functions to encrypt and decrypt terms and also contains the constants $0$ and $\text{TLS\\_AES\\_256\\_GCM\\_SHA384}$ which is a cipher of TLS 1.3.

What we are missing is atomic data to which the functions can be applied to. When modeling security protocols, you typically use the concept of *names* $\mathcal{N} = \\{n, r, s,\dots\\}$. Names can be nonces, random data, session identifiers or keys. There are different subsets of names through, which both have infinitely many names to model the possibility of attackers to choose random values.
$\mathcal{N}\_{pub}$ contains names which are public and available to the attacker e.g. a session identifier like an IP address. 
$\mathcal{N}\_{prv}$ includes private keys of protocol participants. These are usually hidden within the implementations of participants. 

The separation between public and private names is necassary as like in reality data can be private or publicly known in the network. Private names can become known to the attacker by observing it on the network. This gain of knowledge is modeled through a frame, which is introduced later on.

The set of all terms $\mathcal{T}(F,N)$ over the set of functions $F$ and atoms $N$ is defined as: 

{{< katex >}}
\begin{alignat*}{3}
t,t_1,\dots :=    \quad& n            \qquad &\,n \in N \\
                & f(t_1,\dots,t_k)    \qquad &\,f \in F, \text{arity}(f) = k
\end{alignat*}
{{< /katex >}}

If we limit the allowed atoms and functions to $\mathcal{F}$ and $\mathcal{N}$ respectively, then we get the set of all closed terms $\mathcal{T}(\mathcal{F}, \mathcal{N})$. We also call these terms grounded terms.


There are a few helper functions where are defined on terms.
$vars(t)$ describes the set of variables used in the term $t$ and is defined as:

{{< katex >}}
\begin{alignat*}{3}
&vars(t) = vars(f(t_1,\dots,f_n)) = \bigcup_{i=1}^{n} vars(t_i) &\quad\text{if $t$ is a function}\\
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

In order to manipulate terms and transform them we need to introduce the concept of substitution. For that reason we introduce the set of variables $\mathcal{X} = \\{a, b, c, \dots\\}$. Variables are holes in terms which can be filled by other terms. Therefore, a substitution $\sigma$ maps recipe terms $t \in \mathcal{T}(\mathcal{F}, \mathcal{N}_{pub} \cup dom(\sigma))$ to grounded terms $\tilde{t} \in \mathcal{T}(\mathcal{F}, \mathcal{N}$ by filling the variables (or holes). Usually one writes postfix $t\sigma$ instead of $\sigma(t)$ to apply the substitution $\sigma = \\{a \mapsto b, c \mapsto t_2, \dots\\}$. We define the domain of the substitution as $dom(\sigma) = \\{a, b, c, \dots\\} \subseteq \mathcal{X}$. Formally substitution is defined as follows:

{{< katex >}}
\begin{alignat*}{3}
&t\sigma = f(t_1,\dots,f_n)\sigma = f(t_1\sigma),\dots,t_n\sigma))&\quad\text{if $t$ is a function}\\
&t\sigma = t\sigma &\quad\text{if } t \in dom(\sigma)\\
&t\sigma = t
\end{alignat*}
{{< /katex >}}

This means, if we encounter a term which is a function, then we apply the substitution on all arguments. If the term is in $dom(\sigma)$, then we can replace it with the corresponding term in the substitution. If the term is not a function and is not in the domain of $\sigma$, then we do nothing and omit $\sigma$. One might also say that we lift substitutions
homomorphically from variables to terms [^6].
## Fuzzing Input Space

The fuzzer will be able to use the available function symbols $\mathcal{F}$, names $\mathcal{N}$ and learned knowledge to construct arbitrary terms. Indeed, this is the input space of the fuzzer. The semantics of the functions and public names is given by concrete implementations in the fuzzer.

Even though, the fuzzer does not need formal definitions for the semantics of symbols, we still want to provide them here. One might ask why this overhead is beneficial? As already mentioned previously the fuzzer users a bug oracle to decide whether a specific execution of a trace violates a security policy. 

One way to implement a security policy is to look at the obtained knowledge of the attacker during the execution. If the attacker knows $k$ and also witnessed $\text{senc}(x, k)$, then he also knows $x$ even though he never directly observed $x$. If $x \in \mathcal{N}_{prv}$ then we maybe found a security violation. This problem is also known as the *deduction problem*. The problem can be solved by providing a decision procedure which can decide $S \vdash x$, which means whether the term $x$ is deducible from the set $S=\\{\text{senc}(x, k), k\\}$. Note that this problem is in general Turing-complete, but one can restrict the underlying formal model to achieve decidability [^1]. This allows the bug oracle to decide over secrecy. **In practice this is difficult to implement, because we need to know the term structure which is output by the implementations.**

Another way to implement a security policy is to record events over the execution of the trace. These events are also known as claims. For example if we can make the server believe that a client is authenticated, and the client did not claim that it is already authenticated, then we would have an authentication violation. A real-world example for this kind of vulnerability in TLS is the SKIP bug. In a nutshell this vulnerability allows a client attacker with a certificate, but without the private key, to impersonate other clients. The attacker can make the TLS server believe that it has the private key by skipping a message in the TLS protocol.


In conclusion, the fuzzer could have two different ways of expressing semantics for function symbols:
* Semantics via a concrete implementations
* Semantics via a formal model to decide deducibility

The first way can be achieved by defining a term rewriting system which provides a formal way of transforming terms.

Before we take a look at term rewrite systems as a formal model for deducibility we quickly take a look at inference systems which model what an attacker needs to do to deduce a message from an operational point of view.
## Inference Systems

An inference system is defined as a set of rules of the form:

{{< katex >}}
$$
{u_1 \dots u_n \over u}
$$
{{< /katex >}}

where $u_1,\dots, u_n, u$ are terms. 

A simple example looks like this:

{{< katex >}}
\begin{equation*}
\mathcal{I}_{ENC} = \begin{cases}
\begin{alignat*}{3}
{x \quad y \over \langle x,y \rangle}                   &\qquad
{\langle x,y \rangle  \over x}                          &\qquad
{\langle x,y \rangle  \over y}                          \\
{\text{senc}(x,y) \quad y \over x}                      &\qquad
{x \quad y \over \text{senc}(x,y)}                      \\
{\text{aenc}(x,pk(y)) \quad y \over x}                  &\qquad
{x \quad y \over \text{aenc}(x,y)}                      \\
\end{alignat*}
\end{cases}
\end{equation*}
{{< /katex >}}

This models symmetric and asymmetric encryption and decryption, as well as tuples. If an attacker has the symmetrically encrypted plain text and $y$, then he is able to deduce $x$. By following these deduction rules the attacker can also destruct and construct tuples. The system $\mathcal{I}_{ENC}$ is also known as the Dolev-Yao inference system as they firstly lay the foundations for symbolic formalization of security protocols [^5].
### Deduction in Inference Systems

Deduction for inference systems gives an operational view on what an attacker can do, if she has certain knowledge. Later on we will not use this formalism to describe actions of attackers and instead use recipes.

We define deduction as deriving a term $t$ from a set of terms $S$ by using an inference system $\mathcal{I}$. A term is deducible in one-step, denoted by $S \vdash_\mathcal{I}^1 t$ if there exists a rule ${u_1 \dots u_n \over u} \in \mathcal{I}$, terms $t_1, \dots, t_n \in S$ and a substitution $\sigma$, such that $t_i = u_i\sigma$ for $1 \leq i \lt n$ and $t = u\sigma$.

We can extend this definition to $S \vdash_\mathcal{I} t$ by applying inferences rules multiple times. This can be done by building a tree of terms and inference rules.

* The root node is the term $t$,
* all leaves are terms of set $S$, and
* inner nodes, which have a single parent term $t$ and $n$ child terms $t_1,\dots,t_n$, represent a deduction in one-step ${t_1 \dots t_n \over t}$.

If such a proof tree exists, then $S \vdash_\mathcal{I} t$ holds true.

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
\{\text{exp}(\text{exp}(\text{exp}(g, c), b), a)\}\vdash_{\mathcal{I}_{EXP}} \text{exp}(\text{exp}(\text{exp}(g, a), c), b)
$$
{{< /katex >}}

Now lets try to deduce this:

{{< katex >}}
$$
{\text{exp}(\text{exp}(\text{exp}(g, c), b), a) \over \text{exp}(\text{exp}(\text{exp}(g, c), a), b)}
$$
{{< /katex >}}

After applying the first rule, we see that we will never be able to move the $a$ within the most-inner function. We could introduce now a new rule for it, but what if we have 4, 5 or 6 nested exponentiations? Indeed, we would need infinitely many rules in our inference system to model this.

A solution for this problem are equational theories which will be introduced in the next section. Among other functions they allow modeling exponentiation or exclusive-or.

## Equational Theories

Plaisted puts it quite simple: “An equational system is a set of equations.” [^6]. More or less that is also the essence of it. Formally, an equational theory $E$ is defined by a set of pairs $(t_1, t_2)$, where $t_1, t_2 \in \mathcal{T}(\mathcal{F}, \mathcal{X})$. This induces a relation $=_E$ on terms, defined by the smallest equivalence relation $=_E$ that contains all $(t_1, t_2) \in E$, closed under substitution of variables, and under application of function symbols.

A core property of TLS 1.3 and its Diffie Hellman key exchange is that the following equation is true [^7] [^8]:

{{< katex >}}
$
G^{x^y}\,\text{mod}\,p = G^{y^x}\,\text{mod}\,p
$
{{< /katex >}}

Even though they are syntactically different, they both mean the very same. As we saw in the previous section it is not possible to express this equality using inference systems. Therefore, we propose the following equation system:

{{< katex >}}
\begin{equation*}
E_{DH} = \begin{cases}
\begin{alignat*}{2}
\text{sdec}(\text{senc}(x, y), y)&=x &\quad
\text{adec}(\text{aenc}(x, pk(y)), y)&=x \\
\text{exp}(\text{exp}(x, y), z) &= \text{exp}(\text{exp}(x, z), y)  &\quad
\\
%\text{xor}(x, xo\text{r}(y, z))&=xo\text{r}(xo\text{r}(x, y), z)&\quad
%\text{xor}(x, y)&=xo\text{r}(y, x)\\
%\text{xor}(x, x)&=0&\quad
%\text{xor}(x, 0)&=x\\
\end{alignat*}
\end{cases}
\end{equation*}
{{< /katex >}}

Using this equation system we see that 
{{< katex >}}$\{\text{exp}(\text{exp}(G, x), y)\,\text{mod}\,p\} \vdash_{E_{DH}} \text{exp}(\text{exp}(G, y), x)\,\text{mod}\,p${{< /katex >}}
should be true. An in fact Cortier et al. provide a simple inference system which allows us to reuse the definition of deduction trees [^1]:

{{< katex >}}
\begin{align*}
&{ t_1 \dots  t_n \over  f(t_1,\dots,f_n)} \qquad
{ t \over  t'}\quad\text{if $t =_{E_{DH}} t'$}
\end{align*}
{{< /katex >}}

These meta-rules allow us to use the above equational system together with the previous definition of deduction. In general it is undecidable whether two equations are equal given an arbitrary equational system. Therefore, we want to apply restriction on how we want to use the equational system. This is the motivation for term rewriting systems.

## Term Rewriting Systems (TRS)

A term rewriting system $R$ is a finite relation on terms. A rewrite rule is a pair $(\ell, r) \in R$ and can be written as $\ell \rightarrow r$, where $\ell \in \mathcal{T}(\mathcal{F}, \mathcal{X})$ and $r \in \mathcal{T}(\mathcal{F_c}, vars(\mathcal{\ell}))$. Classically, there are two restrictions on rewrite rules as already defined[^3] [^6]:
* The left-hand side term $l$ is not a variable and therefore contains at least one function symbol.
* $r \in \mathcal{T}(\mathcal{F}, vars(\ell))$, which means that each variable which appears on the right-hand side also appears on the left-hand side.
* Function symbols on the right-hand side are constructors instead of destructors. Usually we do not want as a rewrite rule like $\text{pair}(x, y) \rightarrow \text{proj}_2(pair(x, y))$, which would make the rewrite system infinite.

Usually term rewriting systems are done in a way such that the right-hand side is simpler than the left-hand side[^6].
Research of TRS often discusses in which direction rules of an equational system should be defined.

A very important aspect of term rewriting systems is also that they terminate (also known as convergence).
For example the rule $\text{exp}(\text{exp}(x, y), z) \rightarrow \text{exp}(\text{exp}(x, z), y)$ would not make the rewrite system non-convergent.
Therefore, we usually provide some restrictions to achieve convergence.

Before we propose restrictions, firstly some more definitions. We define the relation $R*$ as the reflexive transitive closure of R. One can write $\ell \rightarrow r$ to say that $r$ is derivable in zero or more steps. If $\ell \rightarrow r$ and $r$ is no longer reducible, then we call $r$ the normal form of $r$. We denote this as $s\downarrow$.

In the case of security protocol analysis, we suppose that protocols only send valid messages, which we capture using the $\text{Msg}$ predicate.
We define $\text{Msg}(t)$ to hold if for any sub-term $u \in st(t)$: $u\downarrow\in \mathcal{T}({\cal F}_c, \mathcal{N} \cup \mathcal{X})$. This means that after normalization, only constructor terms are left. If the normalized term still contains a destructor, then we say that the destructor fails. Suppose, we are left with the normalized term $\text{sdec}(\text{h}(x), k)$. In this case, the decryption would fail, as we modeled decrypt in such a way, that we can only decrypt cipher-text and not random data. This corresponds to authenticated encryption (AEAD).
## Computation Relation

A computation relation is a relation of $\mathcal{T}(\mathcal{F}, \mathcal{N}) \times \mathcal{T}(\mathcal{F}_c, \mathcal{N})$, denoted by $\Downarrow$. $t\Downarrow t'$ iif the term $t'$ is computable from the term $t$. Hirischi et. al build this relation using a TRS and an equational system on page 5 [^9]. Refer to that paper for a description on how to build the computational relation given a TRS.

## Towards an Equational Theory for Traces

We already defined term rewrite systems without restrictions. We restrict the rules now, such that it becomes convergent. Each rule of the TRS must have the following structure:

{{< katex >}}
\begin{equation*}
d(t_1,\dots,t_n)\rightarrow r\qquad \text{where } d \in \mathcal{F}_d \text{ of arity } n, t_i \in \mathcal{T}(\mathcal{F}_c, \mathcal{X}) 
\end{equation*}
{{< /katex >}}


We already defined equational theories on all function symbols $\mathcal{F}$. We will restrict this definition now to $\mathcal{F}_c \subseteq \mathcal{F}$. Therefore, for any equational theory $E$ we consider from now on, each $(t_1, t_2) \in E$: $t_1, t_1 \in \mathcal{T}(\mathcal{F}_c, \mathcal{X})$.

With these changes we still can not tell whether arbitrary terms are equal. Right now, the equational system only covers the constructors, while the rewrite system only covers the destructors.
Therefore, We can lift $=_E$ to arbitrary terms and define $t_1 =_E t_2$ to hold if $\text{Msg}(t_1)$ and $\text{Msg}(t_2)$ and $t_1\downarrow =_E t_2\downarrow$.
All operations in this check are decidable.


If an attacker can find a recipe term $t$ such that $t\Phi =_{EQ} t'$, then the attacker can deduce the term $t'$. 

## Modeling the Attacker

In our case a single attacker which has full control over the network is enough to model every possible attack for a TLS client and server setup. This is easy to see as a single attacker can act as multiple attackers. Therefore, the capabilities of a single attacker and multiple attackers coincide.

Every message which is sent by and network participant is witnessed the attacker. The attacker can forward the message to the intended recipient, modify it or just drop and ignore it. Cheval et. al conclude that in such a case the attacker has the following capabilities:
* eavesdropping messages and gain knowledge,
* deduct further terms from messages, like gaining access to a secret if the attacker eavesdropped on the cipher-text and the corresponding key to decrypt it, and
* control messages as the attacker can CRUD messages them and forward them to specific network participants.

Note that we abstract the network topology away. We do not restrict the attacker in any way. The mental model of the attacker corresponds to the  Man-in-the-Middle scenario. In practice the attacker could control an IP router for example.

{{< resourceFigure "ring.drawio.svg" >}}
The red symbol denotes an attacker. The attacker can see and control all traffic in the network.
 {{< /resourceFigure >}}



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

where the handle $h_n \in \mathcal{H}$, the handle index $n \in \mathbb{N}$, $t\ \in \mathcal{T}(\mathcal{F}, N_{pub} \cup \mathcal{H})$ is a term and $u \in \mathcal{S}$. Actions can be concatenated using a $.$ to create a trace which does several things e.g. $\bar{c}(h_1).\text{s}(t_1).\bar{s}(h_2)$. Note that each session identifier $s \in \mathcal{S}$ uniquely identifies a specific agent in the network. We suppose that each agent, referenced by a session identifier, already exists before the execution. That means we do not need to explicitly create agents in the formal model, they just exist as soon as they are referenced. 

### Extended Traces

The set of opaque and abstract states of internal implementation is called $State$. Each $st \in State$ contains the internal states of all network participants. For example at some point in time the state $st \in State$ contains the shared key between a client $c \in \mathcal{S}$ and a server $s \in \mathcal{S}$.

We already mentioned the attacker knowledge already. The attacker knowledge is modeled through a substitution $\Phi$ and is also known as a frame. We gradually extend this frame during the execution of a trace.

Based on this we define the triple $A = (T, st, \Phi)$ as an extended trace:

* $T$ is a closed plain trace
* $st \in State$ is an opaque state which resembles the internal states of all sessions
* $\Phi = \\{ h_1 \mapsto t_1,\dots, h_n \mapsto t_n \\}$, called the frame is a substitution from handles to ground constructor terms

The extended traces, together with their semantics which will follow in the next section, describe what happens when traces are executed. Each execution step can yield information about the inner workings of the implementation under test. We will not formalize this yet, but each step could yield events of claims about what happened. This is comparable to the events of ProVerif. A claim could include for example that a client has authenticated. 

Furthermore, the implementation under test could have crashed. We will also leave this open for now.

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
next: State \times \mathcal{S} \times \mathcal{T}(\mathcal{F}, N_{pub} \cup dom(\Phi) \cup \{\sigma\}) \rightarrow State
\end{equation*}
{{< /katex >}}

The other function gets a single term from a session referenced by a session name in the current state:

{{< katex >}}
\begin{equation*}
out: State \times \mathcal{S} \rightarrow \mathcal{T}(\mathcal{F}, \mathcal{N})
\end{equation*}
{{< /katex >}}

In this theoretical model the output $out(st, s)$ in a given state $st$ of a session $s$ yields a term. In practice the output of a black-box does not have a term-like structure. This makes it difficult to prove certain properties like secrecy, which require a deeper understanding of the output in each trace step. As this is a practical issue, we will not address it here.
## Example Trace Execution

{{< katex >}}
\begin{align*}
T&:=\bar{c}(h_1).\text{s}(t_1).\bar{s}(h_2)\quad&\mathcal{F}_c:=\{\text{CH}/5, \text{senc}/2,\text{sdec}/2,\text{exp}/2\}\\

\mathcal{S}&:=\{c,s\} \subseteq N_{pub} \quad &\mathcal{F}_d:=\{\text{s}/1, \text{r}/1, \text{ex}/1, \text{co}/1, \text{ci}/1, \text{sdec}/2, \text{adec}/2\}\\
State&:=\{s_1, s_2, s_3\} \quad &\mathcal{F}:=\mathcal{F}_c \cup \mathcal{F}_d
\end{align*}


{{< /katex >}}

We use the equational theory $E_{DH}$ together with the following TRS $R$ for the destructors $F_d$:

{{< katex >}}
$$
\text{s}(\text{CH}(x, y, z, d, e)) = x\\
\text{r}(\text{CH}(x, y, z, d, e)) = y\\
\text{ex}(\text{CH}(x, y, z, d, e)) = z\\
\text{co}(\text{CH}(x, y, z, d, e)) = d\\
\text{ci}(\text{CH}(x, y, z, d, e)) = e
$$
{{< /katex >}}

That way we have defined the semantics of all function symbols. The following attacker recipe is an example of what the final fuzzer could do. In this case the fuzzer manipulates the client hello TLS message while it travels form the client $c$ to the server $s$ by setting the examples to an empty set.

{{< katex >}}
$$
\omega := \text{CH}(\text{s}(h_1), \text{r}(h_1), \emptyset, \text{co}(h_1), \text{ci}(h_1))
$$
{{< /katex >}}

{{< resourceFigure "example.drawio.svg" >}}
The dotted rectangle on the lower right shows the syntax of each block. Each state $st \in State$ is visualized by the rounded square. The first line shows the trace until which step it is executed. The second line references the current state, and the last one includes the knowledge of the attacker denoted by the frame $\Phi$.
The rest of the diagram shows an execution of the trace.
 {{< /resourceFigure >}}


## Next Steps

We finished the definition of the ground theory now. Therefore, we continue with the design and implementation phase.

Design Phase:

* Create a glossary
* Design the implementation of tlspuffin
  * Trace, Steps, IO
  * Signature and Terms with Variables, Frames, Attacker Knowledge
* Define the requirements on the Fuzzer in natural language


Implementation Phase:

* Implement the term model and the semantics of the function signature
* Define and execute the trace in Rust
* Generate traces
* Get Feedback from a trace execution
* Integrate into LibAFL

Evaluation Phase:

* Test security violations
* Check coverage

[^1]: Cortier, Véronique, and Steve Kremer. 2014. “Formal Models and Techniques for Analyzing Security Protocols: A Tutorial.” Foundations and Trends® in Programming Languages 1 (3): 151–67. https://doi.org/10.1561/2500000001.
[^2]: Baader, Franz, and Tobias Nipkow. 1998. Term Rewriting and All That. 1st ed. Cambridge University Press. https://doi.org/10.1017/CBO9781139172752.
[^3]: Bezem, M., J. W. Klop, Roel de Vrijer, and Terese (Group), eds. 2003. Term Rewriting Systems. Cambridge Tracts in Theoretical Computer Science, v. 55. Cambridge, UK ; New York: Cambridge University Press.
[^4]: Abadi, Martı́n, and Cédric Fournet. 2001. “Mobile Values, New Names, and Secure Communication.” In Proceedings of the 28th ACM SIGPLAN-SIGACT Symposium on Principles of Programming Languages - POPL 01. ACM Press. https://doi.org/10.1145/360204.360213.
[^5]: Dolev, D., and A. Yao. 1983. “On the Security of Public Key Protocols.” IEEE Transactions on Information Theory 29 (2): 198–208. https://doi.org/10.1109/tit.1983.1056650.
[^6]: Plaisted, David A. 1993. “Equational Reasoning and Term Rewriting Systems.” In Handbook of Logic in Artificial Intelligence and Logic Programming (Vol. 1), 274–364. USA: Oxford University Press, Inc.
[^7]: Diffie, W., and M. Hellman. 1976. “New Directions in Cryptography.” IEEE Transactions on Information Theory 22 (6): 644–54. https://doi.org/10.1109/tit.1976.1055638.
[^8]: Cortier, Véronique, Stéphanie Delaune, and Pascal Lafourcade. 2006. “A Survey of Algebraic Properties Used in Cryptographic Protocols.” Journal of Computer Security 14: 1–43. https://doi.org/10.3233/JCS-2006-14101.
[^9]: Hirschi, Lucca, David Baelde, and Stéphanie Delaune. 2017. “A Method for Unbounded Verification of Privacy-Type Properties,” October. https://via.hypothes.is/https://arxiv.org/pdf/1710.02049.pdf.