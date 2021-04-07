---
layout: post
title: "Symbolid-model Guided Fuzzing"
date: 2021-04-06
slug: symbolic-model-guided
draft: true

katex: true

keywords: []
categories: [research-blog]
---

Traditionally, Fuzzing works on the bit level as "to fuzz" means to "generate a stream of random characters to be consumed by a target program"[^1]. The notion of characters is used equaivalent with bytes here. Fuzzers like AFL start with some seed which could be a JPEG file for example. Then AFL starts to execute the JPEG parser and randomly muates bytes of the input to generate a seed pool. This is done by flipping bits or applying arithmetic operations.

This has major shortcomings when used to fuzz protocols. The messages sent by a protocols often depend on previous messages. This means by randomly flipping bits you maybe not reach deep states within the protocol. Even if you reach good coverage of executed lines, this does not mean that interresting traces of the protocol have been executed.

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

We want to create symbolic traces now from this model.

## Symbolic Traces

### Happy Path Trace

An example for a happy symbolic trace would be:

{{< katex >}}
\begin{align}
spawn(A);spawn(B);\\
\color{red}sk_A = gen\_sk(A); out_A(pk(sk_A));\\
\color{blue}sk_B = hgen\_sk(B);out_B(pk(sk_B)); \\
\color{blue}pk_X = in_B();\\
\color{blue}out_B(aenc(sign((pk_B,pk_X,k_1),sk_B),pk_X)));\\
\color{red}k^{signed} = in_A();\\
\color{red}k = checksign_A(k^{signed},pk_B);\\
\color{red}out_A(senc(message, k));\\
\color{blue}\{message\}_k = in_B();\\
\color{blue}sdec(\{message\}_k, k);
\end{align}
 {{< /katex >}}

Messages in red are triggered by A and those in blue by B.

### Attack Trace

## Linking to Implementations

Now there is some manual work to do to link this to an implementation. We need to transform the symbolic trace to actual function calls of e.g. OpenSSL. Within the library we expose internals through the security context. We add there for example the secrets and the used nonce values.

Now lets jump back to our simple protocol.
More or less one could imagine that a library implementing that protcol could have the following interface:

```typescript
skey gen_sk();
pkey pk(sk: skey);

ByteArray HelloClient(sk_A: pkey);                      // eq. 5
ByteArray HelloServer(sk_B: pkey);                      // eq. 6

(ByteArray, Key) SendNewKey(pk_X: pkey, sk_B: skey);    // eq. 7-8, k is generated
ByteArray RecvKey(pk_B: pkey, sk_A: skey)               // eq. 9-10
            throws SignatureError;

ByteArray SendEncMessage(message: ByteArray, key: Key);     // eq. 11
ByteArray ReceiveEncMessage(message: ByteArray, key: Key);  // eq. 12-13
```

Furthermore, we provide a utility interface:

```typescript
Channel spawn(fn: () => void);                          // eq. 4

// Probably used internally
void send(to: Channel, bytes: ByteArray);
ByteArray receive(from: Channel);
```

The goal of the driver/test harness is now to call the correct entry functions depending on the trace above. Also the security context is filled with the symmetric key $k$ for example.



## Next Steps

[^1]: [Fuzzing Terminology]({{< ref "2021-03-21-fuzzing-terminology" >}}#the-term-fuzzing)
[^2]: [afl-fuzz whitepaper](https://lcamtuf.coredump.cx/afl/technical_details.txt)
[^3]: [Code Coverage](https://en.wikipedia.org/wiki/Code_coverage)
