// ldc2 on macOS is built with -fvisibility=hidden, so these GC entry points
// are not exported into the flat namespace. Provide malloc-backed stubs so
// libdparse can allocate without depending on ldc2's hidden GC symbols.
//
// Note: core.memory.GC.qalloc / GC.extend etc. are the *same* symbols as
// gc_qalloc / gc_extend via pragma(mangle) — calling them here would recurse.

module ldclint.utils.macos_stubs;

version(OSX):

import core.memory : GC;
import core.stdc.stdlib : malloc, abort;
import core.stdc.string : memset;

extern(C) GC.BlkInfo gc_qalloc(size_t sz, uint ba = 0, void* ti = null) nothrow
{
    auto p = malloc(sz);
    if (p is null) abort();
    memset(p, 0, sz);
    return GC.BlkInfo(p, sz, ba);
}

// malloc blocks cannot be extended in-place; caller will re-allocate
extern(C) size_t gc_extend(void* p, size_t mx, size_t sz, void* ti = null) nothrow
{
    return 0;
}

extern(C) void gc_addRange(void* p, size_t sz, void* ti = null) nothrow @nogc {}

extern(C) void gc_removeRange(void* p) nothrow @nogc {}

extern(C) void onOutOfMemoryError(void* = null) @trusted nothrow @nogc
{
    abort();
}

// D invariant check stub — matches __D9invariant12_d_invariantFC6ObjectZv
pragma(mangle, "_D9invariant12_d_invariantFC6ObjectZv")
void _d_invariant_stub(Object o) {}
