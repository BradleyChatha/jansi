<p align="center">
    <img width="128" src="https://i.imgur.com/nG36aGM.png"/>
</p>

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
1. [HOWTO](#howto)
   * Basic usage:
     1. [Enable Windows support](#windows-support)
     1. [Set foreground, background, and styling for a single string](#style-a-single-string)
     1. [Style multiple strings](#style-multiple-strings)
     1. [Output an `AnsiText`](#output-an-ansitext)
     1. [Output via `toString`](#output-with-tostring)
     1. [Output via `toRange`](#output-with-torange)
     1. [Output manually](#output-manually)

   * Advanced usage:
     1. [Custom AnsiText backing implementation](#custom-ansitext-implementation)
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
  
   * User-implemented behavior (e.g. `AnsiText` backings and sinks) have their safety inferred.

* Primitives to work directly with ANSI colour, ANSI styling, and a "style set" consisting of a foreground, background, and styling.

* Wrap singular strings with an ANSI encoding.

* Wrap multiple strings with separate ANSI encodings inside a single data type:
   
   * The data type is highly flexible as it allows user-defined allocation, injection of state variables, and injection of member functions.
   
   * Out of the box, copyable GC-backed and stack-backed implementations are available, as well as a non-copyable RAII `malloc`-backed implementation.

* Execute ANSI SGR commands directly into an `AnsiStyleSet`, in other words parse ANSI SGR sequences.

* Input range that can split up a string by ANSI sequences, and plain text.

* Taking a page from [arsd](https://github.com/adamdruppe/arsd), JANSI commits to being a single-file library with no non-Phobos dependencies:
  
   * [silly](https://code.dlang.org/packages/silly) is used as a test dependency, but it's completely optional and unittests will still work without it.
  
   * Being a single-file makes it painfully easy to include in non-dub environments.

# HOWTO

## Windows Support

By calling `ansiEnableWindowsSupport` JANSI will use `SetConsoleMode` to enable the `ENABLE_VIRTUAL_TERMINAL_PROCESSING` flag, which allows for the use
of ANSI codes:

```d
import jansi;

void main()
{
    // This function is no-op on non-Windows platforms.
    ansiEnableWindowsSupport();
}
```

## Style a single string

This library mainly makes use of function chaining in order to achieve a fluent style of code.

By using `.ansi` you can wrap any form of `char[]` into an `AnsiTextLite`, which you can then use `.fg`, `.bg`, and `.style` in order
to set the foreground, background, and styling:

```d
import jansi, std;

void main()
{
    ansiEnableWindowsSupport();
    writeln(
        "Hello".ansi.bg(Ansi4BitColour.black).fg(Ansi8BitColour(219)).style(AnsiStyle.init.underline),
        ", ",
        "World!".ansi.bg(Ansi4BitColour.red).fg(AnsiRgbColour(255, 255, 255)).style(AnsiStyle.init.bold.italic)
    );
}
```

Results in (italic not supported by my terminal):

![style-a-single-string-output](https://i.imgur.com/9SwzvnC.png)

## Style multiple strings

There is a need for storing multiple ANSI-encoded strings into a singular data type. While one may first think "arrays!" there's a flaw: consider that this library is -betterC compatible and so RAII, or ref-counting, or any other form of manual memory management may be useful to have contained within its own type.

In comes `AnsiText`, which is a very flexible type which is mostly defined by external backing implementations (you could try [making your own backing](#custom-ansitext-implementation) for it.), but I'll go on about that more from within the advanced usage section.

There are three implementations provided out of the box:
    * `AnsiTextGC` - **Not compiled under -betterC**. A copyable implementation that uses GC memory.
    * `AnsiTextMalloc` - A non-copyable implementation that uses `malloc` and `free` directly. Frees memory in its dtor.
    * `AnsiTextStack!CAPACITY` - A copyable implementation that uses a static array for its memory.

Each implementation documents its own uses, warnings, and additions to the base `AnsiText` type, so for `basic usage` we'll just stick with the bare-bones usage, and
go with `AnsiTextGC` for simplicity.

In its simplest form, usage of an `AnsiText` implementation is almost the same as using a normal D output range:

```d
import jansi, std;

void main()
{
    AnsiTextGC text;
    text.put("Hello, ".ansi.fg(Ansi4BitColour.red));
    text.put("World!".ansi.style(AnsiStyle.init.underline));

    writeln(text);
}
```

Outputting from an `AnsiText` is discussed more in a [section below](#output-an-ansitext) as this simple `writeln` usage obviously doesn't work in -betterC.

## Output an AnsiText

Every backing implementation of `AnsiText` must define a `toSink` function that takes a "sink" of any type. It's completely up to the implementation to choose
what it supports.

However, all built-in implementations (and just as a general recommendation, **all* implementations should do this) support a sink where the sink is an output range that accepts `char[]`s. This means that custom implementations will have to document their own ways of being used, so this README will only explain usage of the built-in implementations.

So let's explore a few options that are provided to us.

### Output with toSink

As explained above, `toSink` is simply a function that (in the built-in case) takes a normal D output range that accepts character slices.

Just to show an example, we'll make an output range that simply calls `printf` directly for every slice it is given:

```d
import jansi, core.stdc.stdio;

struct PrintfOutputRange
{
    @nogc
    void put(const(char)[] slice)
    {
        assert(slice.length <= int.max);
        printf("%.*s", cast(int)slice.length, &slice[0]);
    }
}

@nogc
void main()
{
    AnsiTextMalloc text;
    text.put("Hello, world!".ansi.style(AnsiStyle.init.underline));
    // text.put(...)

    PrintfOutputRange range;
    text.toSink(range);
}
```

The sink can be whatever is needed. For example, the standard Phobos `Appender!(char[])` can be used as a sink where you can then retrieve the final value from.

### Output with auto-generated toString

*This feature is not compiled in -betterC.*

Because it can be annoying for implementations to support both -betterC, and some common non-betterC conveniences, `AnsiText` will automatically generate two overloads of `toString` for the implementation under the following circumstances:
    * The implementation doesn't define its own form of `toString`.
    * JANSI isn't being compiled under -betterC.
    * The implementation's `toSink` function can take an output range that accepts `char[]`s.

The following overloads are generated:

```d
string toString();
void toString(scope void delegate(const(char)[]) sink);
```

Where the first `toString` works as you expect it to - it'll call `toSink` and put all of the slices into a singular, GC-allocated `string.

Whereas the second `toString` is a special "sink-based" overload recognised by the likes of `writeln`, which allows `AnsiText` to be printed with minimal (if any) allocations.

For an example, see either the [style multiple strings](#style-multiple-strings) section, or the [output with toString](#output-with-tostring) below, which both feature usage of these non-betterC-only functions.

Of course, the backing implementation can define its own -betterC compatible `toString` if it desires.

## Output with toString

*This feature is not compiled in -betterC.*

Most of the data types in this library will provide a `toString` that creates and returns GC-allocated string.

Some types, (such as `AnsiTextLite` and sometimes `AnsiText`) will contain two overloads:
    * A `string toString()` which functions as you'd expected.
    * A `void toString(scope void delegate(const(char)[]))` which is a special sink-based overload recognised by Phobos.

The sink-based overload is used by the likes of `writeln`, so that the data type can avoid needless allocations.

So, building on from there:

```d
import jansi, std;

void main()
{
    ansiEnableWindowsSupport();
    auto text = "Hello".ansi.fg(AnsiRgbColour.white).bg(AnsiRgbColour.green);

    // Using the sink-based toString to avoid allocations (unless writeln allocates).
    writeln(text);

    // Directly using the parameterless toString to allocate a new string.
    writeln(text.toString());
}
```

## Output with toRange

**@safe warning:** Some of the slices returned by `toRange` will be slices of stack-allocated memory, please do not persist slices past a range object without copying its data.

**Note:** Slices are not null-terminated by default, but ranges return data in a well-defined order, with lengths that are well-defined (except for the user-defined text), so statically allocated buffers are possible to use. Order is: start ANSI sequence -> user-defined text -> end ANSI sequence.

Some types will expose a range interface to the user, as an easy and well-known way of avoiding the need to allocate memory.

### Non-betterC output

```d
import jansi, std;

void main()
{
    foreach(slice; "Hello, world!".ansi.toRange)
        write(slice);
    writeln();
}
```

### BetterC output (buffer with null terminator)

```d
import jansi, core.stdc.stdio;

@nogc
void main() nothrow
{
    // AnsiTextLite.MAX_CHARS_NEEDED describes, at most, how many characters are
    // required for the **ANSI start and end sequences**, but **not the user-defined string**.
    ansiEnableWindowsSupport();

    enum BUFFER_SIZE = AnsiTextLite.MAX_CHARS_NEEDED + 200; // + 200 to account for a small-sized user string.
    char[BUFFER_SIZE] buffer;

    foreach(slice; "Hello, world!".ansi.toRange)
    {
        assert(slice.length < buffer.length);
        buffer[0..slice.length] = slice[];
        buffer[slice.length] = '\0';
        printf("%s", &buffer[0]);
    }
}
```

### BetterC output (no buffer or allocations needed)

```d
import jansi, core.stdc.stdio;

void main()
{
    // By using printf's ".*s" specifier, we can pass the length of a string directly
    // so we don't need to mess around with null terminators.

    ansiEnabledWindowsSupport();

    foreach(slice; "Hello, world!".ansi.toRange)
        printf("%.*s", cast(int)slice.length, &slice[0]);
}
```

### Persisting range results

Because some of the slices are to stack-allocated memory, you'll need to persist the data if the data is to outlive the range object.

This is just an example:

```d
import jansi, std;

void main()
{
    auto range = "Hello".ansi
                        .toRange
                        .map!(slice => slice.idup) // Or anything equivalent.
                        ...;
}
```


### Persisting range results (-betterC)

As above, this is just a plain example that doesn't necessarily leak slices outside of their lifetimes, but shows how you could persist data:

```d
import jansi, std.algorithm;

void main()
{
    char[500] buffer;
    auto range = "Hello".ansi
                        .toRange
                        .map!((slice){ buffer[0..slice.length] = slice[]; })
                        ...;
}
```

## Output manually

While all of the above options are provided out of convenience, they are all usually built on top of functions that are intended for a more manual style of output handling.

### For AnsiTextLite

For `AnsiTextLite` there are three properties that are to be used for manual output: `AnsiText.toFullStartSequence`, `AnsiText.text`, and `AnsiText.toFullEndSequence`.

The `toFullStartSequence` function takes a reference to a static array of a known size; populates it with non-null-terminated data, and then returns the slice
from that buffer containing all of the characters inserted into it.

The `toFullEndSequence` function returns a static array containing its data. It doesn't require an external buffer because the length of the output isn't dynamic.

The `.text` field is simply the same slice passed into `AnsiTextLite` from the user's code, so no weird allocation needed unless you need a null-terminator.

Here's an example of using `AnsiTextLite` manually:

```d
import jansi, core.stdc.stdio;

void main()
{
    ansiEnableWindowsSupport();

    auto text = "Hello, world!".ansi
                               .fg(Ansi4BitColour.red)
                               .bg(Ansi4BitColour.black)
                               .style(AnsiStyle.init.underline);

    // In this example we'll use printf's ability to print strings with a known size,
    // instead of null terminators.

    char[AnsiTextLite.MAX_CHARS_NEEDED] startBuffer;
    const startSlice = text.toFullStartSequence(/*ref*/ startBuffer);

    const textSlice = text.text; // This is just the "Hello, world!" we passed into `.ansi`

    const end = text.toFullEndSequence();

    printf(
        "%.*s%.*s%.*s",
        cast(int)startSlice.length, &startSlice[0],
        cast(int)textSlice.length,  &textSlice[0],
        cast(int)end.length,        &end[0]
    );
}
```

### For AnsiText

Please see the [AnsiText](#style-multiple-strings) section for more details, as `AnsiText` is quite unique in this regard.

### For AnsiColour, AnsiStyle, and AnsiStyleSet

**Note:** These types will only output their *commands* without the ANSI CSI and ANSI SGR marker, e.g `1;2;38;2;255;255;255`. For manual usage you must sandwich this output between the `ANSI_CSI` string at the start, and the `ANSI_COLOUR_END` character at the end.

Each of these types has a statically-known max output length, which is defined as the per-type `MAX_CHARS_NEEDED` constant (e.g. `AnsiStyle.MAX_CHARS_NEEDED`).

Each of these types also expose a `toSequence` function defined as:

```d
char[] toSequence(ref return char[MAX_CHARS_NEEDED] buffer) @safe @nogc nothrow const;
```

The `buffer` parameter is a reference to an external static array which is then populated with type's data.

Because the output length is dynamic (with a statically known max length), these `toSequence` functions will also return a slice from `buffer` which contains the part of the `buffer` that was populated by the function.

Manual usage is quite simple, if not a bit bulky:

```d
import jansi, core.stdc.stdio;

void main()
{
    ansiEnableWindowsSupport();

    // `AnsiStyleSet` is convenient when we need a fg, bg, and styling, as it also correctly manages separating commands with the ANSI_SEPARATOR (';') character.
    AnsiStyleSet set = AnsiStyleSet.init
                                   .fg(Ansi4BitColour.red)
                                   .bg(Ansi4BitColour.brightMagenta)
                                   .style(AnsiStyle.init.underline.italic);
    
    char[AnsiStyleSet.MAX_CHARS_NEEDED] buffer;
    const bufferSlice = set.toSequence(/*ref*/ buffer);

    // Format string broken down:
    //  %s   - ANSI_CSI to signal the start of an ANSI command sequence.
    //  %.*s - The ANSI commands from our style set.
    //  %c   - ANSI_COLOUR_END to signal the end of the sequence, and that the sequence is for styling + colour.
    //  %s   - The text to output
    //  %s   - The ANSI_COLOUR_RESET sequence will simply resets all colouring and styling to default, for all text after it.
    printf("%s%.*s%c%s%s",
        ANSI_CSI.ptr, // Constant string defined by jansi. String literals are null terminated so this is safe.
        cast(int)bufferSlice.length, &buffer[0],
        ANSI_COLOUR_END, // Constant char defined by jansi.
        "Hello, world!".ptr,
        ANSI_COLOUR_RESET.ptr // See: ANSI_CSI
    );
}
```

## Custom AnsiText implementation

I've done plenty of talk about how "flexible" `AnsiText` is, so how would one go about making their own backing implementation, and what does it allow them to actually do?

First of all I highly recommend you look at the documentation for `AnsiText`, as it goes into some details that I may not cover here.

The overall structure can be explained as: `AnsiText` is a templated struct that defines a common set of functions, which relies on certain functions being implemented by a user-provided mixin template.

This can be seen if you were to inspect the source code for `AnsiText` - it defines a `put` function with a few overloads, and has additional logic for [generating a toString](#output-an-ansitext) under certain conditions. However, you'll notice that it doesn't actually define any member variables or memory management of any sort, it instead delegates that to a mixin template provided the user (`AnsiText`'s first template parameter).

So what does this magical mixin template actually look like? Well:

```d
mixin template MyImpl()
{
    enum Features = AnsiTextImplementationFeatures.basic;

    char[] newSlice(size_t minLength);
    void toSink(Sink)(Sink); // Doesn't have to be a template, could have separate overloads of specific types or whatever you want.
}

alias AnsiTextMyImpl = AnsiText!MyImpl;
```

First of all is the `Features` enum, this is used to tell `AnsiText` about any unique features/behaviors it can take advantage of, mold it's code around, etc.

Currently there's only `.basic`, which is defined as "Supports at least `.put`, `.toSink`, `char[] .newSlice`, and allows `AnsiText` to handle the encoding".

Next up is the `newSlice` function. `AnsiText` will call this function and expects to be given a slice of memory that contains of at least `minLength` length. 

Finally, the `toSink` function which has been explained to death in the basic usage section. The sink can be whatever type(s) you want to support, but try to always support an output range of `char[]`s.

A very interesting opportunity occurs here due to the fact that implementations are `mixin template`s - they can inject member variables, directly provide new functions onto the `AnsiType` struct, add dtors, ctors, copy ctors, etc. Even operator overloading if you for some reason want that.

Your implementation essentially has full ability to customise the `AnsiText` struct to its liking, which along side the ability to inject member variables, allows your implementation to provide whatever memory management scheme you require.

For example, let's make a very basic (and probably buggy) malloc-based implementation and use it:

```d
import jansi, std;

mixin template MyImpl()
{
    import std.experimental.allocator.mallocator, std.experimental.allocator;

    enum Features = AnsiTextImplementationFeatures.basic;

    private const(char)[] _name;
    private char[][] _slices;

    @disable this(this){}

    ~this()
    {
        if(this._slices !is null)
        {
            foreach(slice; this._slices)
                Mallocator.instance.dispose(slice);
            Mallocator.instance.dispose(this._slices);
        }
    }

    this(const(char)[] name)
    {
        this._name = name;
    }

    char[] newSlice(size_t minLength)
    {
        auto slice = Mallocator.instance.makeArray!char(minLength);
        if(this._slices is null)
            this._slices = Mallocator.instance.makeArray!(char[])(1);
        else
            Mallocator.instance.expandArray(this._slices, 1);
        this._slices[$-1] = slice;
        return slice;
    }

    void toSink(Sink)(ref scope Sink sink)
    if(isOutputRange!(Sink, char[]))
    {
        sink.put(this._name);
        foreach(slice; this._slices)
            sink.put(slice);
        sink.put(ANSI_COLOUR_RESET);
    }

    // Custom stuff
    size_t length()
    {
        return this._slices.length;
    }
}

alias AnsiTextMyImpl = AnsiText!MyImpl;

void main()
{
    auto text = AnsiTextMyImpl("Test: ");
    text.put("Hello, world!".ansi);

    writeln(text.toString()); // Test: Hello, world!
}
```

Hopefully if you're already considering making an `AnsiText` implementation the above doesn't really need much explanation.

I should note however that you'll need to make sure to include any needed imports directly inside the `mixin template`.

# Versions

| Version       | Description                                                      |
|---------------|------------------------------------------------------------------|
| JANSI_BetterC | Forces JANSI to compile as if it was compiling under `-betterC`. |

# Contributing

I'm perfectly accepting of anyone wanting to contribute to this library, just note that it might take me a while to respond.
