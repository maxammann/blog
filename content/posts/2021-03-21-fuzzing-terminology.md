---
layout: post
title: "Fuzzing Terminology"
date: 2021-03-21T14:00:33+01:00
slug: fuzzing-terminology
draft: false
wip: true

keywords: [ ]
categories: [ fuzzing ]
---


Research in Fuzzing has gained a lot of traction in the last decade. A lot of open source fuzzers have been implemented and are available on Github. Everyone who already developed any application knows the pain of naming things. It is very difficult to have a common understanding of the terms used in a project. A standard software engineering practice is to use a glossary. This usually only scaled to a team or a small company but not to thousands of fuzzers on Github.
Also, documentation is more of a gimmick than a comprehensive guide in most projects.

Therefore, the paper "The Art, Science, and Engineering of Fuzzing" tries to create a common terminology of fuzzing. It also gives a simple common view on how fuzzers work and includes a major survey of fuzzers and their relations to each other.
In this post I'll try to give an overview of the terminology.

## The Term "Fuzzing"

The term "to fuzz" describes a program which "generates a stream of random characters to be consumed by a target program" [^1]. And this is actually what a 
fuzzer is doing. It sends random input to a program to test it for reliability.
Miller et al. wrote a tool called `fuzz` to test Unix utilities. The source code of it can be found [here](https://github.com/dyninst/fuzz/blob/master/src/fuzz.c). One could argue that this is the first fuzzer!

A recent publication by Miller asks whether fuzz testing is solved by now [^2]. **I want to read this paper in the future.**


## Terminology

Now lets dive into the terminology. I want to do this in a table and give short explanations.

|Term|Description|
|---|---|
|PUT|Program Under Test|
|Fuzz Input Space|Space of inputs for the PUT|
|Fuzzing|Execution of a PUT with input from the fuzz input space|
|Security Policy|e.g. "PUT does not write outside of indented memory", "PUT follows the TLS state machine" [^3]|
|Fuzz Testing|Use of fuzzing to test whether a PUT violates a security policy|
|Fuzzer|The program which fuzz tests the PUT|
|Fuzz Campaign|Specific execution of the PUT|
|Bug Oracle|Decides if an execution violates the security policy|
|Fuzz Configuration|Parameters of the Fuzzer program|
|Seed|(Well-)structured input of the PUT which is mutated while fuzzing|
|Seed Pool|Collection of seeds|
|Seed Trimming|Reduce size of a seed without reducing quality like keeping same execution coverage|
|Driver Application|Helper program around the PUT to execute it. For example a wrapper about a library. This is also called a test harness|

One may ask what the difference between fuzzing and software testing is. From a technical point of view there isn't any. Both try to find bugs in software.
But there is a significant difference in the intention of fuzzing.
The term fuzzing is mostly used for security related testing [^4]. Often source code is not available when testing for security issues. Usually when testing software as a software engineer you have the source code which allows you to write unit tests.

<!-- TODO Lucca:
* fuzzing is one testing paradigm (so one is one particular case of the other)
* fuzzing is designed to reach a high coverage, ideally 100% while unitary testing might not reach such coverage level that easily
* fuzzing is often fully automated
* fuzzing scales better.
-->

## Usual implementation of a Fuzzer

Manes et al. give a good overview the algorithm behind fuzzers [^4]. Of course this is very simplified. LibAFL uses a distributed fuzzing architecture with a broker and multiple clients for example.

```python
bug_oracle = ...

def fuzz(fuzz_configs):
  bugs = []

  while continue(fuzz_configs):
    config = schedule(fuzz_configs)
    concrete_test_cases = input_gen(config)
    
    new_bugs, exec_feedback = input_eval(config, concrete_test_cases, bug_oracle)
    
    fuzz_configs = conf_update(fuzz_configs, config, exec_feedback)
    bugs = bugs.union(new_bugs)
    
  return bugs
```

I used pseudo-python code here and descriptive names to avoid writing what it does. It should be quite easy to understand.

## Model-based vs Model-less Fuzzers

The goal of my master thesis will be to fuzz a TLS library. The approach we want to go is model guided. But what does that mean?

According to the literature research by Manes et al. there are model-based fuzzers and model-less fuzzers [^4].  The two approaches differ in the way how the inputs to the PUT are generated. Inputs can be generated using a model like a grammar or they are randomly generated by flipping bits of a seed.

Model-based fuzzers can further be divided into fuzzers which use a predefined or inferred models. Predefined models are for example grammars for text-based network protocols or descriptions of binary protocols.
Inferred models are derived from datasets. That means the burden of designing the model is no longer on the fuzzer developers. Manes et al. mention that only a few fuzzers use this technique [^4].

Maybe this could be beneficial for my model-guided approach to fuzzing. There is already related work by PULSAR [^6], who infer a model from network captures and Ruiter et. al who used this technique to **fuzz TLS** [^5].

Model-less fuzzers use the already mentioned seeds. A seed can be a text file, binary file or a network packet. Then bits are flipped in the seed to yield new inputs.

## Optimization Opportunities

There are multiple points at which fuzzers can be optimized. Notably the important points are the function in the pseudo-code above:

|Fn|Opportunity|
|---|---|
|schedule|Choosing configurations based on good algorithms (AFL uses an evolutionary algorithm)|
|input_gen|Generate good inputs which trigger bugs|
|input_eval|Faster execution by using in-memory fuzzing or avoiding stdout|
|conf_update|For evolutionary algorithms: choose a good fitness indicator|

<!-- 
TODO Lucca:
another opportunity is to increase the coverage.
the survey nicely explains the inherent tension in fuzzing: trying to prioritize test cases that are likely to trigger bugs versus trying to prioritize semantically diverse/radically different test cases that will increase the coverage or another metric and that could later become better candidates to find a bug. Focusing too much on the first one -> get stuck in one portion of the code and never find a bug. Focusing too much on the second one -> solely optimizing the wrong metric (improving the coverage or another metric) will lead to miss bugs.
-->

An other way to improve fuzzing coverage or speed is to skip checksum checks. For example it is notoriously difficult to generate an input which passes the checksum AND triggers a bug. This is also called PUT mutation.

<!-- TODO: Lucca: Another approach to address this problem is to use the "encoder model": fuzz the plaintext and then apply the genuine function that computes the checksum (as opposed to fuzz the whole plaintext+checksum). -->

## Guided Fuzzing

Guided fuzzing includes an additional analysis to guide the fuzzer. According to  Manes et al. there are two phases:

* initial (static) program analysis
* generate concrete test cases with the guidance of the analysis

An example for this is the hot bytes analysis in TaintScope. They used a taint analysis to find input bytes which "flow into critical systems". **For my thesis this could mean that I first analyze the TLS engine and then use these results to guide the fuzzer.** By analyzing a lightly-annotated state machine of a TLS engine I could find out which input lead to certain states.


## LibAFL and Google terms

LibAFL is a framework for fuzzing. You could compare it to TensorFlow, just for Fuzzing. Their terminology is similar, but of course adjusted to the AFL world.

The cool thing is that you can just read about the used terms in their documentation. There is also the [AFL glossary](https://github.com/google/fuzzing/blob/master/docs/glossary.md) which includes some of the terms used in LibAFL.

|Term|Description|
|---|---|
|Target|Same as a PUT|
|Corpus|Same as a seed pool|
|Executor|Executes the PUT|
|Generator|Generates random numbers and characters|
|Observers|Observe information about the PUT during execution|
|Feedback|Information retrieved about an execution, like execution time, crashes. Also determines whether the execution was interesting.|
|Mutators|Mutate seeds and input the PUT|
|Stats|Statistics about the fuzzing progress, speed etc.|
|Cross-pollination|Using input generated for a target for another target.|
|Dictionary|Set of tokens which should be processed together while mutating|
|Reproducer/Test Case|Test input which can be used to trigger a bug|

[^1]: [An empirical study of the reliability of UNIX utilities](https://dl.acm.org/doi/10.1145/96267.96279) p. 34 "The Tools"

[^2]: [The Relevance of Classic Fuzz Testing :Have We Solved This One?](https://arxiv.org/pdf/2008.06537.pdf)
[^3]: The security policy should be observable from the actual execution. If the execution leaks for example the reached lines of code, then this can be included in the security policy. For example a security policy could be. "Never reach line 42 in `state_machine.c`". In LibAFL, everything that is observable can be found in the `Feedback` API. That means you give the feedback of an execution to a Bug Oracle and let it determine whether a security policy has been violated.
[^4]: [The Art, Science, and Engineering of Fuzzing](https://arxiv.org/abs/1812.00140)
[^5]: [ProtocolstatefuzzingofTLSimplementations](https://www.usenix.org/system/files/conference/usenixsecurity15/sec15-paper-de-ruiter.pdf)
[^6]: [Pulsar: Stateful Black-Box Fuzzing of Proprietary Network Protocols](https://link.springer.com/chapter/10.1007/978-3-319-28865-9_18)