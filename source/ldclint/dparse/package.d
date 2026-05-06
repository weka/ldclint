module ldclint.dparse;

import ldclint.utils.report;

import dparse.rollback_allocator : RollbackAllocator;
import dparse.parser;
import dparse.lexer;
import dparse.ast;
import dparse.formatter;

import std.conv : to;
import std.typecons : Flag;
import std.string : toStringz;

import DMD = ldclint.dmd;

private __gshared Module[void*] dparseMap;

Module dparseModule(Flag!"parserErrors" parserErrors, DMD.Module mod, string filename)
{
    if (!mod) return null;

    auto omod = cast(void*)mod;
    if (auto m = omod in dparseMap) return *m;

    static ubyte[] skipBOM(ubyte[] data)
    {
        if (data.length >= 3 && data[0 .. 3] == "\xef\xbb\xbf")
            return data[3 .. $];

        return data;
    }

    RollbackAllocator rba;
    StringCache cache = StringCache(StringCache.defaultBucketCount);
    LexerConfig config = {
        fileName       : filename,
        stringBehavior : StringBehavior.source,
    };

    auto source = skipBOM(cast(ubyte[])mod.src);
    auto tokens = getTokensForParser(source, config, &cache);

    void outputError(
        string fileName,
        size_t lineNumber,
        size_t columnNumber,
        string message,
        bool err,
    )
    {
        if (!parserErrors) return;

        // dmd.Loc became opaque in D 2.111 (LDC 1.41): the only public
        // factory keeping a filename is singleFilename, and it carries no
        // line/column info. We bypass the DMD diagnostic plumbing on those
        // versions and emit the message ourselves so libdparse line numbers
        // surface in the conventional `path(line): Kind: msg` form.
        static if (__VERSION__ >= 2111)
        {
            import std.stdio : stderr;
            stderr.writefln("%s(%d): %s: %s",
                fileName, lineNumber,
                err ? "Error" : "Warning",
                message);
        }
        else
        {
            auto loc = DMD.Loc(toStringz(fileName), lineNumber.to!uint, columnNumber.to!uint);
            if (err) error(loc, toStringz(message));
            else     warning(loc, toStringz(message));
        }
    }

    return dparseMap[omod] = parseModule(tokens, config.fileName, &rba, &outputError);
}
