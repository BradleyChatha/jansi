module jansi;

import std.range : isOutputRange;
import std.typecons : Flag;

/+++ CONSTANTS +++/

version(JANSI_BetterC)
{
    private enum BetterC = true;
}
else
{
    private enum BetterC = false;
}

alias IsBgColour = Flag!"isBg";
alias AnsiOnly = Flag!"ansiOnly";
alias Ansi8BitColour = ubyte;

immutable ANSI_CSI                = "\033[";
immutable ANSI_SEPERATOR          = ';';
immutable ANSI_COLOUR_END         = 'm';
immutable ANSI_COLOUR_RESET       = ANSI_CSI~"0"~ANSI_COLOUR_END;
immutable ANSI_FG_TO_BG_INCREMENT = 10;

/+++ COLOUR TYPES +++/

/++
 + Defines what type of colour an `AnsiColour` stores.
 + ++/
enum AnsiColourType
{
    /// Default, failsafe.
    none,

    /// 4-bit colours.
    fourBit,

    /// 8-bit colours.
    eightBit,

    /// 24-bit colours.
    rgb
}

/++
 + An enumeration of standard 4-bit colours.
 +
 + These colours will have the widest support between platforms.
 + ++/
enum Ansi4BitColour
{
    // To get Background code, just add 10
    black           = 30,
    red             = 31,
    green           = 32,
    /// On Powershell, this is displayed as a very white colour.
    yellow          = 33,
    blue            = 34,
    magenta         = 35,
    cyan            = 36,
    /// More gray than true white, use `BrightWhite` for true white.
    white           = 37,
    /// Grayer than `White`.
    brightBlack     = 90,
    brightRed       = 91,
    brightGreen     = 92,
    brightYellow    = 93,
    brightBlue      = 94,
    brightMagenta   = 95,
    brightCyan      = 96,
    brightWhite     = 97
}

@safe
struct AnsiRgbColour
{
    union
    {
        ubyte[3] components;

        struct {
            ubyte r;
            ubyte g;
            ubyte b;
        }

        uint asInt; // Last byte is unused.
    }

    @safe @nogc nothrow pure:

    this(ubyte[3] components)
    {
        this.components = components;
    }

    this(ubyte r, ubyte g, ubyte b)
    {
        this.r = r;
        this.g = g;
        this.b = b;
    }

    this(uint asInt)
    {
        this.asInt = asInt;
    }
}

private union AnsiColourUnion
{
    Ansi4BitColour fourBit;
    Ansi8BitColour eightBit;
    AnsiRgbColour  rgb;
}

@safe
struct AnsiColour
{
    static immutable FG_MARKER        = "38";
    static immutable BG_MARKER        = "48";
    static immutable EIGHT_BIT_MARKER = '5';
    static immutable RGB_MARKER       = '2';

    enum MAX_CHARS_NEEDED = "38;2;255;255;255".length;

    private
    {
        AnsiColourUnion _value;
        AnsiColourType  _type;
        IsBgColour      _isBg;

        @safe @nogc nothrow
        this(IsBgColour isBg) pure
        {
            this._isBg = isBg;
        }
    }

    /// A variant of `.init` that is used for background colours.
    static immutable bgInit = AnsiColour(IsBgColour.yes);

    /+++ CTORS AND PROPERTIES +++/
    @safe @nogc nothrow pure
    {
        // Seperate, non-templated constructors as that's a lot more documentation-generator-friendly.
        this(Ansi4BitColour colour, IsBgColour isBg = IsBgColour.no)
        {
            this = colour;
            this._isBg = isBg;
        }
        
        this(Ansi8BitColour colour, IsBgColour isBg = IsBgColour.no)
        {
            this = colour;
            this._isBg = isBg;
        }

        this(AnsiRgbColour colour, IsBgColour isBg = IsBgColour.no)
        {
            this = colour;
            this._isBg = isBg;
        }

        this(ubyte r, ubyte g, ubyte b, IsBgColour isBg = IsBgColour.no)
        {
            this(AnsiRgbColour(r, g, b), isBg);
        }

        this(T)(T colour, IsBgColour isBg = IsBgColour.no)
        if(isUserDefinedRgbType!T)
        {
            this = colour;
            this._isBg = isBg;
        }

        auto opAssign(T)(T colour) return
        if(!is(T == typeof(this)))
        {
            static if(is(T == Ansi4BitColour))
            {
                this._value.fourBit = colour;
                this._type = AnsiColourType.fourBit;
            }
            else static if(is(T == Ansi8BitColour))
            {
                this._value.eightBit = colour;
                this._type = AnsiColourType.eightBit;
            }
            else static if(is(T == AnsiRgbColour))
            {
                this._value.rgb = colour;
                this._type = AnsiColourType.rgb;
            }
            else static if(isUserDefinedRgbType!T)
            {
                this = colour.to!AnsiColour();
            }
            else static assert(false, "Cannot implicitly convert "~T.stringof~" into an AnsiColour.");
            
            return this;
        }

        /// Returns: The `AnsiColourType` of this `AnsiColour`.
        @property
        AnsiColourType type() const
        {
            return this._type;
        }

        /// Returns: Whether this `AnsiColour` is for a background or not (it affects the output!).
        @property
        IsBgColour isBg() const
        {
            return this._isBg;
        }

        /// ditto
        @property
        void isBg(IsBgColour bg)
        {
            this._isBg = bg;
        }

        /// ditto
        @property
        void isBg(bool bg)
        {
            this._isBg = cast(IsBgColour)bg;
        }

        /++
        + Assertions:
        +  This colour's type must be `AnsiColourType.fourBit`
        +
        + Returns:
        +  This `AnsiColour` as an `Ansi4BitColour`.
        + ++/
        @property
        Ansi4BitColour asFourBit() const
        {
            assert(this.type == AnsiColourType.fourBit);
            return this._value.fourBit;
        }

        /++
        + Assertions:
        +  This colour's type must be `AnsiColourType.eightBit`
        +
        + Returns:
        +  This `AnsiColour` as a `ubyte`.
        + ++/
        @property
        ubyte asEightBit() const
        {
            assert(this.type == AnsiColourType.eightBit);
            return this._value.eightBit;
        }

        /++
        + Assertions:
        +  This colour's type must be `AnsiColourType.rgb`
        +
        + Returns:
        +  This `AnsiColour` as an `AnsiRgbColour`.
        + ++/
        @property
        AnsiRgbColour asRgb() const
        {
            assert(this.type == AnsiColourType.rgb);
            return this._value.rgb;
        }
    }
    
    /+++ OUTPUT +++/

    static if(!BetterC)
    {
        @trusted nothrow
        string toString() const
        {
            import std.exception : assumeUnique;

            auto chars = new char[MAX_CHARS_NEEDED];
            return this.toSequence(chars[0..MAX_CHARS_NEEDED]).assumeUnique;
        }
        ///
        @("AnsiColour.toString")
        unittest
        {
            assert(AnsiColour(255, 128, 64).toString() == "38;2;255;128;64");
        }
    }

    // For a sink that's a pre-made, statically sized buffer.
    @safe @nogc
    char[] toSequence(ref return char[MAX_CHARS_NEEDED] buffer) nothrow const
    {
        if(this.type == AnsiColourType.none)
            return null;

        size_t cursor;

        void numIntoBuffer(ubyte num)
        {
            char[3] text;
            const slice = numToStrBase10(text[0..3], num);
            buffer[cursor..cursor + slice.length] = slice[];
            cursor += slice.length;
        }

        if(this.type != AnsiColourType.fourBit)
        {
            // 38; or 48;
            auto marker = (this.isBg) ? BG_MARKER : FG_MARKER;
            buffer[cursor..cursor+2] = marker[0..$];
            cursor += 2;
            buffer[cursor++] = ANSI_SEPERATOR;
        }

        // 4bit, 5;8bit, or 2;r;g;b
        final switch(this.type) with(AnsiColourType)
        {
            case none: assert(false);
            case fourBit: 
                numIntoBuffer(cast(ubyte)((this.isBg) ? this._value.fourBit + 10 : this._value.fourBit)); 
                break;

            case eightBit:
                buffer[cursor++] = EIGHT_BIT_MARKER;
                buffer[cursor++] = ANSI_SEPERATOR;
                numIntoBuffer(this._value.eightBit);
                break;
                
            case rgb:
                buffer[cursor++] = RGB_MARKER;
                buffer[cursor++] = ANSI_SEPERATOR;

                numIntoBuffer(this._value.rgb.r); 
                buffer[cursor++] = ANSI_SEPERATOR;
                numIntoBuffer(this._value.rgb.g); 
                buffer[cursor++] = ANSI_SEPERATOR;
                numIntoBuffer(this._value.rgb.b); 
                break;
        }

        return buffer[0..cursor];
    }
    ///
    @("AnsiColour.toSequence(char[])")
    unittest
    {
        char[AnsiColour.MAX_CHARS_NEEDED] buffer;

        void test(string expected, AnsiColour colour)
        {
            const slice = colour.toSequence(buffer);
            assert(slice == expected);
        }

        test("32",               AnsiColour(Ansi4BitColour.green));
        test("42",               AnsiColour(Ansi4BitColour.green, IsBgColour.yes));
        test("38;5;1",           AnsiColour(Ansi8BitColour(1)));
        test("48;5;1",           AnsiColour(Ansi8BitColour(1), IsBgColour.yes));
        test("38;2;255;255;255", AnsiColour(255, 255, 255));
        test("48;2;255;128;64",  AnsiColour(255, 128, 64, IsBgColour.yes));
    }
}

/+++ MISC TYPES +++/
enum AnsiSgrStyle
{
    none      = 0,
    bold      = 1,
    dim       = 2,
    italic    = 3,
    underline = 4,
    slowBlink = 5,
    fastBlink = 6,
    invert    = 7,
    strike    = 9
}

private template getMaxSgrStyleCharCount()
{
    import std.traits : EnumMembers;

    // Can't even use non-betterC features in CTFE, so no std.conv.to!string :(
    size_t numberOfChars(int num)
    {
        size_t amount;

        do
        {
            amount++;
            num /= 10;
        } while(num > 0);

        return amount;
    }

    size_t calculate()
    {
        size_t amount;
        static foreach(member; EnumMembers!AnsiSgrStyle)
            amount += numberOfChars(cast(int)member) + 1; // + 1 for the semi-colon after.

        return amount;
    }

    enum getMaxSgrStyleCharCount = calculate();
}

@safe
struct AnsiStyle
{
    enum MAX_CHARS_NEEDED = getMaxSgrStyleCharCount!();

    private
    {
        ushort _sgrBitmask; // Each set bit index corresponds to the value from `AnsiSgrStyle`.

        @safe @nogc nothrow
        int sgrToBit(AnsiSgrStyle style) pure const
        {
            return 1 << (cast(int)style);
        }

        @safe @nogc nothrow
        void setSgrBit(bool setOrUnset)(AnsiSgrStyle style) pure
        {
            static if(setOrUnset)
                this._sgrBitmask |= this.sgrToBit(style);
            else
                this._sgrBitmask &= ~this.sgrToBit(style);
        }

        @safe @nogc nothrow
        bool getSgrBit(AnsiSgrStyle style) pure const
        {
            return (this._sgrBitmask & this.sgrToBit(style)) > 0;
        }
    }

    // Seperate functions for better documentation generation.
    //
    // Tedious, as this otherwise could've all been auto-generated.
    /+++ SETTERS +++/
    @safe @nogc nothrow pure
    {
        AnsiStyle reset() return
        {
            this._sgrBitmask = 0;
            return this;
        }

        AnsiStyle set(AnsiSgrStyle style, bool enable) return
        {
            if(enable)
                this.setSgrBit!true(style);
            else
                this.setSgrBit!false(style);
            return this;
        }

        AnsiStyle bold(bool enable = true) return { this.setSgrBit!true(AnsiSgrStyle.bold); return this; }
        AnsiStyle dim(bool enable = true) return { this.setSgrBit!true(AnsiSgrStyle.dim); return this; }
        AnsiStyle italic(bool enable = true) return { this.setSgrBit!true(AnsiSgrStyle.italic); return this; }
        AnsiStyle underline(bool enable = true) return { this.setSgrBit!true(AnsiSgrStyle.underline); return this; }
        AnsiStyle slowBlink(bool enable = true) return { this.setSgrBit!true(AnsiSgrStyle.slowBlink); return this; }
        AnsiStyle fastBlink(bool enable = true) return { this.setSgrBit!true(AnsiSgrStyle.fastBlink); return this; }
        AnsiStyle invert(bool enable = true) return { this.setSgrBit!true(AnsiSgrStyle.invert); return this; }
        AnsiStyle strike(bool enable = true) return { this.setSgrBit!true(AnsiSgrStyle.strike); return this; }
    }

    /+++ GETTERS +++/
    @safe @nogc nothrow pure const
    {
        bool get(AnsiSgrStyle style)
        {
            return this.getSgrBit(style);
        }
        
        bool bold() { return this.getSgrBit(AnsiSgrStyle.bold); }
        bool dim() { return this.getSgrBit(AnsiSgrStyle.dim); }
        bool italic() { return this.getSgrBit(AnsiSgrStyle.italic); }
        bool underline() { return this.getSgrBit(AnsiSgrStyle.underline); }
        bool slowBlink() { return this.getSgrBit(AnsiSgrStyle.slowBlink); }
        bool fastBlink() { return this.getSgrBit(AnsiSgrStyle.fastBlink); }
        bool invert() { return this.getSgrBit(AnsiSgrStyle.invert); }
        bool strike() { return this.getSgrBit(AnsiSgrStyle.strike); }
    }

    /+++ OUTPUT +++/

    static if(!BetterC)
    {
        @trusted nothrow
        string toString() const
        {
            import std.exception : assumeUnique;

            auto chars = new char[MAX_CHARS_NEEDED];
            return this.toSequence(chars[0..MAX_CHARS_NEEDED]).assumeUnique;
        }
    }

    @safe @nogc
    char[] toSequence(ref return char[MAX_CHARS_NEEDED] buffer) nothrow const
    {
        import std.traits : EnumMembers;

        if(this._sgrBitmask == 0)
        {
            //buffer[0] = '0';
            //return buffer[0..1];
            return null;
        }

        size_t cursor;
        void numIntoBuffer(uint num)
        {
            char[10] text;
            const slice = numToStrBase10(text[0..$], num);
            buffer[cursor..cursor + slice.length] = slice[];
            cursor += slice.length;
        }

        bool isFirstValue = true;
        static foreach(flag; EnumMembers!AnsiSgrStyle)
        {{
            if(this.getSgrBit(flag))
            {
                if(!isFirstValue)
                    buffer[cursor++] = ANSI_SEPERATOR;
                isFirstValue = false;

                numIntoBuffer(cast(uint)flag);
            }
        }}

        return buffer[0..cursor];
    }
    ///
    @("AnsiStyle.toSequence(char[])")
    unittest
    {
        char[AnsiStyle.MAX_CHARS_NEEDED] buffer;
        
        void test(string expected, AnsiStyle style)
        {
            const slice = style.toSequence(buffer);
            assert(slice == expected, "Got '"~slice~"' wanted '"~expected~"'");
        }

        test("", AnsiStyle.init);
        test("1;2;3", AnsiStyle.init.bold.dim.italic);
    }
}

/+++ DATA WITH COLOUR TYPES +++/
@safe
struct AnsiChar
{
    enum MAX_CHARS_NEEDED = (AnsiColour.MAX_CHARS_NEEDED * 2) + AnsiStyle.MAX_CHARS_NEEDED + 2; // + 2 for the char itself and the end marker.

    private AnsiColour _fg;
    private AnsiColour _bg;
    AnsiStyle style;
    char value;

    // As usual, functions are manually made for better documentation.

    /+++ SETTERS +++/
    @safe @nogc nothrow
    {
        AnsiChar fg(AnsiColour colour) return { this._fg = colour; this._fg.isBg = IsBgColour.no; return this; }
        AnsiChar fg(Ansi4BitColour colour) return { return this.fg(AnsiColour(colour)); }
        AnsiChar fg(Ansi8BitColour colour) return { return this.fg(AnsiColour(colour)); }
        AnsiChar fg(AnsiRgbColour colour) return { return this.fg(AnsiColour(colour)); }

        AnsiChar bg(AnsiColour colour) return { this._bg = colour; this._bg.isBg = IsBgColour.yes; return this; }
        AnsiChar bg(Ansi4BitColour colour) return { return this.bg(AnsiColour(colour)); }
        AnsiChar bg(Ansi8BitColour colour) return { return this.bg(AnsiColour(colour)); }
        AnsiChar bg(AnsiRgbColour colour) return { return this.bg(AnsiColour(colour)); }

        AnsiChar chainStyle(AnsiStyle style) return { this.style = style; return this; }
        AnsiChar chainValue(char ch) return { this.value = ch; return this; }
    }

    /+++ GETTERS +++/
    @safe @nogc nothrow const
    {
        AnsiColour fg() { return this._fg; }
        AnsiColour bg() { return this._bg; }
    }

    /+++ OUTPUT ++/
    @safe @nogc
    char[] toSequence(ref return char[MAX_CHARS_NEEDED] buffer, AnsiOnly ansiOnly = AnsiOnly.no) nothrow const
    {
        size_t cursor;

        char[AnsiColour.MAX_CHARS_NEEDED] colour;
        char[AnsiStyle.MAX_CHARS_NEEDED] style;

        auto slice = this._fg.toSequence(colour);
        buffer[cursor..cursor + slice.length] = slice[];
        cursor += slice.length;

        slice = this._bg.toSequence(colour);
        if(slice.length > 0 && cursor > 0)
            buffer[cursor++] = ANSI_SEPERATOR;
        buffer[cursor..cursor + slice.length] = slice[];
        cursor += slice.length;

        slice = this.style.toSequence(style);
        if(slice.length > 0 && cursor > 0)
            buffer[cursor++] = ANSI_SEPERATOR;
        buffer[cursor..cursor + slice.length] = slice[];
        cursor += slice.length;

        if(!ansiOnly)
        {
            buffer[cursor++] = ANSI_COLOUR_END;
            buffer[cursor++] = this.value;
        }

        return buffer[0..cursor];
    }
    ///
    @("AnsiChar.toSequence")
    unittest
    {
        char[AnsiChar.MAX_CHARS_NEEDED] buffer;

        void test(string expected, AnsiChar ch, AnsiOnly ansiOnly)
        {
            auto slice = ch.toSequence(buffer, ansiOnly);
            assert(slice == expected, "Got '"~slice~"' expected '"~expected~"'");
        }

        test("ma", AnsiChar.init.chainValue('a'), AnsiOnly.no);
        test("", AnsiChar.init.chainValue('a'), AnsiOnly.yes);
        test(
            "32;48;2;255;128;64;1;4ma", 
            AnsiChar.init
                    .fg(Ansi4BitColour.green)
                    .bg(AnsiRgbColour(255, 128, 64))
                    .chainStyle(AnsiStyle.init.bold.underline)
                    .chainValue('a'),
            AnsiOnly.no
        );
    }
}

enum AnsiTextImplementationFeatures
{
    basic = 0, // Supports at least `.put`, `.toSink`, `char[] .newSlice`, and allows `AnsiText` to handle the encoding.
}

struct AnsiText(alias ImplementationMixin)
{
    mixin ImplementationMixin;
    alias ___TEST = TestAnsiTextImpl!(typeof(this));

    void put()(const(char)[] text, AnsiColour fg = AnsiColour.init, AnsiColour bg = AnsiColour.bgInit, AnsiStyle style = AnsiStyle.init)
    {
        fg.isBg = IsBgColour.no;
        bg.isBg = IsBgColour.yes;

        char[AnsiChar.MAX_CHARS_NEEDED] sequence;
        auto sequenceSlice = AnsiChar.init.fg(fg).bg(bg).chainStyle(style).toSequence(sequence, AnsiOnly.yes);

        auto minLength = ANSI_CSI.length + sequenceSlice.length + /*ANSI_COLOUR_END*/1 + text.length;
        char[] slice = this.newSlice(minLength);
        size_t cursor;

        void appendToSlice(const(char)[] source)
        {
            slice[cursor..cursor+source.length] = source[];
            cursor += source.length;
        }

        appendToSlice(ANSI_CSI);
        appendToSlice(sequenceSlice);
        slice[cursor++] = ANSI_COLOUR_END;
        appendToSlice(text);
    }

    // Generate a GC-based toString if circumstances allow.
    static if(
        Features == AnsiTextImplementationFeatures.basic
     && !__traits(hasMember, typeof(this), "toString")
     && !BetterC
    )
    {
        string toString()()
        {
            import std.array : Appender;
            import std.exception : assumeUnique;

            Appender!(char[]) output;
            this.toSink(output);

            return ()@trusted{return output.data.assumeUnique;}();
        }
    }
}

private template TestAnsiTextImpl(alias TextT)
{
    // Ensures that the implementation has the required functions, and that they can be used in every required way.
    static assert(__traits(hasMember, TextT, "Features"),
        "Implementation must define: `enum Features = AnsiTextImplementationFeatures.xxx;`"
    );
    static assert(__traits(hasMember, TextT, "newSlice"),
        "Implementation must define: `char[] newSlice(size_t minLength)`"
    );
    static assert(__traits(hasMember, TextT, "toSink"),
        "Implementation must define: `void toSink(Sink)(Sink sink)`"
    );
}

@("AnsiText.toString - Autogenerated GC-based")
unittest
{
    import std.format : format;

    void genericTest(AnsiTextT)(AnsiTextT text)
    {
        text.put("Hello, ");
        text.put("Wor", AnsiColour(1, 2, 3), AnsiColour(3, 2, 1), AnsiStyle.init.bold.underline);
        text.put("ld!", AnsiColour(Ansi4BitColour.green));

        auto str      = text.toString();
        auto expected = "\033[mHello, \033[38;2;1;2;3;48;2;3;2;1;1;4mWor\033[32mld!\033[0m";

        assert(
            str == expected, 
            "Got is %s chars long. Expected is %s chars long\nGot: %s\nExp: %s".format(str.length, expected.length, [str], [expected])
        );
    }

    genericTest(AnsiTextGC.init);
    genericTest(AnsiTextMalloc.init);
}

static if(!BetterC)
{
    // Very naive implementation just so I have something to start off with.
    mixin template AnsiTextGCImplementation()
    {
        private char[][] _slices;

        enum Features = AnsiTextImplementationFeatures.basic;

        @safe
        char[] newSlice(size_t minLength) nothrow
        {
            this._slices ~= new char[minLength];
            return this._slices[$-1];
        }

        void toSink(Sink)(ref Sink sink)
        if(isOutputRange!(Sink, char[]))
        {
            foreach(slice; this._slices)
                sink.put(slice);
            sink.put(ANSI_COLOUR_RESET);
        }
    }
    alias AnsiTextGC = AnsiText!AnsiTextGCImplementation;
}

mixin template AnsiTextMallocImplementation()
{
    import std.experimental.allocator.mallocator, std.experimental.allocator;

    enum Features = AnsiTextImplementationFeatures.basic;

    // Again, very naive implementation just to get stuff to show off.
    private char[][] _slices;

    // Stuff like this is why I went for this very strange design decision of using user-defined mixin templates.
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

    void toSink(Sink)(ref Sink sink)
    if(isOutputRange!(Sink, char[]))
    {
        foreach(slice; this._slices)
            sink.put(slice);
        sink.put(ANSI_COLOUR_RESET);
    }
}
alias AnsiTextMalloc = AnsiText!AnsiTextMallocImplementation;

/+++ PUBLIC HELPERS +++/
enum isUserDefinedRgbType(CT) =
(
    __traits(hasMember, CT, "r")
 && __traits(hasMember, CT, "g")
 && __traits(hasMember, CT, "b")
);

AnsiColour to(T : AnsiColour, CT)(CT colour)
if(isUserDefinedRgbType!CT)
{
    return AnsiColour(colour.r, colour.g, colour.b);
}
///
@("to!AnsiColour(User defined)")
@safe @nogc nothrow pure
unittest
{
    static struct RGB
    {
        ubyte r;
        ubyte g;
        ubyte b;
    }

    assert(RGB(255, 128, 64).to!AnsiColour == AnsiColour(255, 128, 64));
}

AnsiColour toBg(T)(T c)
{
    auto colour = to!AnsiColour(c);
    colour.isBg = IsBgColour.yes;
    return colour;
}
///
@("toBg")
@safe @nogc nothrow pure
unittest
{
    static struct RGB
    {
        ubyte r;
        ubyte g;
        ubyte b;
    }

    assert(RGB(255, 128, 64).toBg == AnsiColour(255, 128, 64, IsBgColour.yes));
}

/+++ PRIVATE HELPERS +++/
private char[] numToStrBase10(NumT)(char[] buffer, NumT num)
{
    if(num == 0)
    {
        if(buffer.length > 0)
        {
            buffer[0] = '0';
            return buffer[0..1];
        }
        else
            return null;
    }

    const CHARS = "0123456789";

    ptrdiff_t i = buffer.length;
    while(i > 0 && num > 0)
    {
        buffer[--i] = CHARS[num % 10];
        num /= 10;
    }

    return buffer[i..$];
}
///
@("numToStrBase10")
unittest
{
    char[2] b;
    assert(numToStrBase10(b, 32) == "32");
}