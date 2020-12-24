# Overview

![Build and Test](https://github.com/BradleyChatha/jansi/workflows/Build%20and%20Test/badge.svg)

JANSI is betterC-compatible library that aids with writing and reading ANSI-encoded text.

Similar to [JCLI](https://github.com/BradleyChatha/jcli) I aim to achieve a decent quality of documentation, something
which is often sorely lacking in the D community :(

It also goes without saying that results across platforms is near impossible to keep consistent due to platform and terminal differences, so it's
up to your own code to decide which platforms/terminals/whatever it wants to support.

That said, most terminals handle ANSI colours properly (Older Windows might choke on RGB colours, I'm not too sure), so using colours, especially
4-bit colours, should be relatively safe to use. Note that each terminal defines its own pallette, so non-RGB colours aren't guaranteed to look nice
between terminals... because that's just how ANSI support is.

1. [Overview](#overview)
1. [Features](#features)
1. [Versions](#versions)
1. [Contributing](#contributing)

# Features

* -betterC compatible, with non-betterC code conditionally compiled for those that still want convenience:
  * As a result, most of the codebase is `@nogc nothrow`.
  * Most of the data types support one or more of: outputting to a sink (output range); provide an input range interface; or expose stack-allocated values to allow manual usage.
  * Most data types also provide a `toString` that uses the GC if not used with -betterC, as well as the sink-based version of `toString` for even less allocations.
  * Unittests that are not -betterC compatible are conditionally compiled.
  * -betterC should be automatically detected, but you can also define the version `JANSI_BetterC` to prevent non-betterC code from generating.
* Entirely `@safe`, although certain usage is weakly-safe, as the user code can perform unsafe behavior, but D doesn't really give me any tools to stop that from happening:
  * Potential unsafe behavior is documented where relevant.
* Primitives to work directly with ANSI colour, ANSI styling, and a "style set" consisting of a foreground, background, and styling.
* Wrap singular strings with an ANSI encoding.
* Wrap multiple strings with separate ANSI encodings inside a single data type:
  * The data type is highly flexible as it allows user-defined allocation, injection of state variables, and injection of member functions.
* Execute ANSI SGR commands directly into an `AnsiStyleSet`, in other words parse ANSI SGR sequences.
* Input range that can split up a string by ANSI sequences, and plain text.
* Taking a page from [arsd](https://github.com/adamdruppe/arsd), JANSI commits to being a single-file library with no non-Phobos dependencies:
  * [silly](https://code.dlang.org/packages/silly) is used as a test dependency, but it's completely optional and unittests will still work without it.
  * Being a single-file makes it painfully easy to include in non-dub environments.

# Versions

| Version       | Description                                                      |
|---------------|------------------------------------------------------------------|
| JANSI_BetterC | Forces JANSI to compile as if it was compiling under `-betterC`. |

# Contributing

I'm perfectly accepting of anyone wanting to contribute to this library, just note that it might take me a while to respond.