module ldclint.utils.sections;

import ldc.attributes : hidden, assumeUsed;
import std.traits: EnumMembers, hasUDA, isType;

version(OSX)
{
    // On macOS (Mach-O), ELF-style __start_*/__stop_* linker symbols do not
    // exist. Instead, use getsectiondata() with the dylib's Mach-O header.
    private extern(C) struct mach_header_64 {}
    private extern extern(C) __gshared mach_header_64 _mh_dylib_header;
    private extern(C) void* getsectiondata(
        const(mach_header_64)* mhp,
        const(char)* segname,
        const(char)* sectname,
        ulong* size,
    ) nothrow @nogc;

    pragma(inline, true)
    @trusted @nogc nothrow @hidden
    void[] sectionSlice(string sectionName)()
    {
        enum segname = "__DATA\0";
        enum sectname = sectionName ~ "\0";
        ulong size;
        void* data = getsectiondata(&_mh_dylib_header, segname.ptr, sectname.ptr, &size);
        if (data is null) return null;
        return data[0 .. size];
    }
}
else
{
    @assumeUsed @hidden
    private static void* _addNothingInSection(string sectionName)()
    {
        import ldc.attributes : assumeUsed, section;

        @assumeUsed @section(sectionName)
        __gshared void[0] nothing = (void[0]).init;

        return &nothing;
    }

    template sectionRef(string pos, string sectionName)
        if(pos == "start" || pos == "stop")
    {
        import ldc.attributes : assumeUsed;

        alias _ = _addNothingInSection!(sectionName);

        // The code below references the magic linker symbols __start_* / __stop_*
        // to prevent that the compiler/linker discards the sections
        pragma(mangle, "__" ~ pos ~ "_" ~ sectionName)
        @assumeUsed @hidden extern extern(C) __gshared void* sectionRef;
    }

    @hidden
    void* sectionStartPtr(string sectionName)()
    {
        alias _ = _addNothingInSection!(sectionName);
        return cast(void*)&sectionRef!("start", sectionName);
    }

    alias sectionPtr = sectionStartPtr;

    @hidden
    void* sectionStopPtr(string sectionName)()
    {
        alias _ = _addNothingInSection!(sectionName);
        return cast(void*)&sectionRef!("stop", sectionName);
    }

    pragma(inline, true)
    @trusted @nogc nothrow @hidden
    ptrdiff_t sectionOffset(string sectionName, alias sym)()
        if(hasUDA!(sym, section(sectionName(s, channel))))
        out(offset)
        {
            assert(offset >= 0,
                "offset of section `" ~ sectionName ~ "` must be >= 0"
            );
        }
    do
    {
        alias _ = _addNothingInSection!(sectionName);
        return cast(void*)&sym - sectionPtr!(sectionName);
    }

    pragma(inline, true)
    @trusted @nogc nothrow @hidden
    ptrdiff_t sectionOffset(string sectionName)(void* ptr)
        out(offset)
        {
            assert(offset >= 0,
                "offset of section `" ~ sectionName ~ "` must be >= 0"
            );
        }
    do
    {
        alias _ = _addNothingInSection!(sectionName);
        return ptr - sectionPtr!(sectionName);
    }

    pragma(inline, true)
    @trusted @nogc nothrow @hidden
    ptrdiff_t sectionSize(string sectionName)()
    {
        alias _ = _addNothingInSection!(sectionName);
        return sectionStopPtr!(sectionName) - sectionStartPtr!(sectionName);
    }

    pragma(inline, true)
    @trusted @nogc nothrow @hidden
    void[] sectionSlice(string sectionName)()
    {
        alias _ = _addNothingInSection!(sectionName);
        return sectionPtr!(sectionName)[0 .. sectionSize!(sectionName)];
    }

    @trusted @nogc nothrow @hidden
    immutable(char)* storeStringInSection(string sectionName, string str)()
    {
        static if (str.length > 0)
        {
            // FIXME: Don't need this template after 2.94.x @@BACKPORT@@
            template _storeStringInSection()
            {
                import std.string : indexOf;
                static assert (str.indexOf("\x00") < 0, "string must not contain null character");

                @section(sectionName) align(1)
                __gshared immutable(char)[str.length+1] _storeStringInSection = str ~ '\x00';
            }

            return _storeStringInSection!().ptr;
        }
        else
            return null;
    }

    @trusted @nogc nothrow @hidden
    immutable(void)* storeDataInSection(string sectionName, alias Tvalue)()
        if(!isType!Tvalue)
    {
        template _storeDataInSection()
        {
            @assumeUsed @section(sectionName) align(1)
            __gshared immutable(typeof(Tvalue)) _storeDataInSection = Tvalue;
        }

        return cast(void*)&_storeDataInSection!();
    }
}
