---
layout: post
title: "Symbolic-model Guided Fuzzing"
date: 2021-04-06
slug: symbolic-model-guided
draft: true

katex: true

keywords: []
categories: [research-blog]
---

Traditionally, Fuzzing works on the bit level as "to fuzz" means to "generate a stream of random characters to be consumed by a target program"[^1]. The notion of characters is used equivalent with bytes here. Fuzzers like AFL start with some seed which could be a JPEG file for example. Then AFL starts to execute the JPEG parser and randomly mutates bytes of the input to generate a seed pool. This is done by flipping bits or applying arithmetic operations.

This has major shortcomings when used to fuzz protocols. The messages sent by a protocols often depend on previous messages. This means by randomly flipping bits you maybe not reach deep states within the protocol. Even if you reach good coverage of executed lines, this does not mean that interesting traces of the protocol have been executed.

This is also mentioned in the [AFL README](https://github.com/google/AFL/blob/fab1ca5ed7e3552833a18fc2116d33a9241699bc/README.md#1-challenges-of-guided-fuzzing): "Unfortunately, fuzzing is also relatively shallow; blind, random mutations make it very unlikely to reach certain code paths in the tested code, leaving some vulnerabilities firmly outside the reach of this technique".
The AFL approach uses branch (edge) coverage [^2]. That means that every edge between two code blocks in a control flow graph have been visited by the PUT. They use a clever method to instrument programs efficiently to detect differences between the two execution traces `A -> B` and `B -> A`, where `A` and `B` are code blocks. AFL uses three variables `cur_location`, `shared_mem` and `prev_location`.
Firstly, `curr_location` is set to a random value which is generated when instrumenting the program:

```c
cur_location = <COMPILE_TIME_RANDOM>;
```

Next we XOR the current location and the previous location and increment a counter at that position in the shared memory map:

```c
shared_mem[cur_location ^ prev_location]++;
```

Now we shift `cur_location` once to the right to detect differences between `A -> B` and `B -> A`.

```c
prev_location = cur_location >> 1;
```

There are a lot of different ways to express coverage [^3]. The following figure shows their relative power. One could also say that path coverage subsumes all other coverage methods. MC/DC is not comparable to boundary interior.

{{< resourceFigure "hierarchy.svg" "Strukturelle Testmethoden: Vergleich [A. Knapp]" >}}Strukturelle Testmethoden: Vergleich [A. Knapp]{{< /resourceFigure >}}

Generally, it is not possible to test all paths as there could be infinitely many. Take for example a loop which loops a long as `b` is `true`. As it is not known how long `b` will stay true, the program could loop endlessly.

Therefore, our goal is to cover all "interesting" paths of our protocol. In my thesis I want to tackle this problem of determining "interesting" by using symbolic models.

## Big Picture

Below you can see a sketch of the big picture.

{{< resourceFigure "big-picture.drawio.svg" >}}
We derive symbolic traces from a symbolic model. These traces are put into a seed pool. From this seed pool we randomly draw a symbolic trace. We not execute that trace using some implementation like OpenSSL. The trace through the implementation is called concrete trace. We want to gather now information about the concrete execution. Firstly, we use this information to create a security context which can be checked by a bug oracle. Secondly we use information from the execution, like symbolic coverage to mutate the symbolic trace and evaluate the performance of it. 
 {{< /resourceFigure >}}

## Symbolic Model Example

Let's use as a first example the naïve handshake protocol from the [ProVerif manual p. 12](https://prosecco.gforge.inria.fr/personal/bblanche/proverif/manual.pdf).

{{< katex >}}
\begin{align}
A \rightarrow B:& \; pk(sk_A) \\
B \rightarrow A:& \; aenc(sign((pk(sk_B),k),sk_B),pk(sk_A)) \\
A \rightarrow B:& \; senc(s, k)
\end{align}
 {{< /katex >}}

The model of this protocol looks like this:

{{< readfile file="./handshake_model.pv" highlight="systemverilog" >}}

Note that this model has an attack hidden! This means the query `query attacker(message)` evaluates to true.

We want to create symbolic traces now from this model.

## Happy Path Trace

An example for a happy symbolic trace would be:

{{< katex >}}
\begin{align}
A := spawn\_session(); B := spawn\_session();\\
\color{green}sk_A := gen\_sk(); out(pk(sk_A));\\
\color{blue}sk_B := gen\_sk();out(pk(sk_B)); \\
\color{blue}pk_X := in();\\
\color{blue}out(aenc(sign((pk_B,k),sk_B),pk_X)));\\
\color{green}k^{signed} := in();\\
\color{green}k := checksign_A(k^{signed},pk_B);\\
\color{green}out(senc(message, k));\\
\color{blue}encMessage := in();\\
\color{blue}sdec(encMessage, k).
\end{align}
 {{< /katex >}}

Messages in green are triggered by $A$ and those in blue by $B$.

## Attack Trace

{{< katex >}}
\begin{align}
A := spawn\_session(); B := spawn\_session();\\
\color{green}sk_A := gen\_sk(); out(pk(sk_A));\\
\color{blue}sk_B := gen\_sk();out(pk(sk_B)); \\

\color{red}sk_E := gen\_sk(E); out(pk(sk_E));\\

\color{blue}\overbrace{pk_X}^{\text{pk of Eve}} := in();\\ 
\color{blue}out(aenc(sign((pk_B,k_1),sk_B),pk_X)));\\

\color{red}out(aenc(sign((pk_B,k_1),sk_B),\overbrace{pk_A}^{\rightarrow \text{Attacking A}})));\\

\color{green}k^{signed} := in();\\
\color{green}k := checksign(k^{signed},pk_B);\\
\color{green}out(senc(message, k));\\

\color{red}encMessage := in();\\
\color{red}sdec(encMessage, k).
\end{align}
 {{< /katex >}}

Messages in orange are from the attacker $E$.
The attacker got access to the $message$ by reusing the signature created by $B$.
The visual attack trace can be inspected [here](./trace_attack.svg).

{{< resourceFigure "trace_attack.svg" >}}
Visualization of the attack trace.
{{< /resourceFigure >}}

## Linking to Implementations

Now there is some manual work to do to link this to an implementation. We need to transform the symbolic trace to actual function calls of e.g. OpenSSL. Within the library we expose internals through the security context. We add there for example the secrets and the used nonce values.

Now lets jump back to our simple protocol.
More or less one could imagine that a library implementing that protocol could have the following interface:

```typescript
type Context = {
    channel: Channel,
    sk: skey,
    k: Key
}

skey gen_sk()
pkey pk(sk: skey)

ByteArray HelloClient(ctx, sk_A: pkey)                          // eq. (5)
ByteArray HelloServer(ctx, sk_B: pkey)                          // eq. (6)

pkey ReceiveHello(ctx)                                          // eq. (7)

ByteArray SendNewKey(ctx, pk_X: pkey, sk_B: skey)               // eq. (8), k is generated
Key RecvKey(ctx, pk_B: pkey, sk_A: skey)                        // eq. (9-10)
            throws SignatureError

ByteArray SendEncMessage(ctx, message: ByteArray, key: Key)     // eq. (11)
ByteArray ReceiveEncMessage(ctx, message: ByteArray, key: Key)  // eq. (12-13)
```

An example concrete trace would be:

```typescript
let c = new Channel()
let ctxClient = c.newContext()
let ctxServer = c.newContext()

let skA: skey = gen_sk()
let skB: skey = gen_sk()

// We suppose in our model that keys are preshared.
let pkA: pkey = pk(skA)
let pkB: pkey = pk(skB)

HelloClient(ctxClient, skA)
HelloServer(ctxServer, skB)
let pkX: pkey = ReceiveHello(ctxServer)
SendNewKey(ctxServer, pkX, skB)
let k: = ReceiveKey(ctxClient, pkB, skA)
SendEncMessage(ctxClient, "Hello World!", k)
let message = ReceiveEncMessage(ctxSer er, k)
```

The goal of the driver/test harness is now to call the correct entry functions depending on the trace above.

 Also the security context is filled with the symmetric key $k$ for example. Also when running `SendNewKey` we store the identity of the sender and the receiver. That could be **B** and **E** for example. When running `ReceiveKey` we also store store the sender and receiver. The pair of sender and receiver does not match, but the implementation did not through the `SignatureError` then the bug oracle detected an authentication violation.

Now this is very specific and just some guessing very specific to this example. ProVerif already provides queries to detect security properties. Like for example secrecy of a message `query attacker(message)` or authentication: `query x:key,y:pkey; event(termClient(x,y))==>event(acceptsServer(x,y))`. These queries define connections between events. Events can be triggered and recorded in the security context. After adding an event the security context can be checked by the bug oracle. The oracle then decides whether the context contains violations. For example for a given symmetric key `x` and public key `y`, if `termClient(x,y)` happens but `acceptsServer(x,y)` hasn't been recorded yet then we have an authentication violation.

Therefore, the bug oracle is a function of: `Violations[] ask_oracle(securityCtx: SecurityContext)`. You provide it a security context and the oracle decides which violations are contained.
## Next Steps

* Take a look on the OpenSSL/rustls/Go entry functions
* Take a look at the TLS ProVerif model


[^1]: [Fuzzing Terminology]({{< ref "2021-03-21-fuzzing-terminology" >}}#the-term-fuzzing)
[^2]: [afl-fuzz whitepaper](https://lcamtuf.coredump.cx/afl/technical_details.txt)
[^3]: [Code Coverage](https://en.wikipedia.org/wiki/Code_coverage)
0