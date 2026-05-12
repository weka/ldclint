module ldclint.plugin;

import ldclint.checks;
import ldclint.options;
import ldclint.utils.visitor : Visitor;

import std.typecons : Flag, Yes, No;

import core.sync.mutex : Mutex;

/// Registry of Check singletons keyed by their `ClassInfo`. The first
/// `runSemanticAnalysis` to hit a given check class instantiates it; every
/// subsequent call reuses the same instance, so check-local state
/// (visited-node sets, output file handles, accumulated scopes, etc.) is
/// preserved across the whole compile.
private __gshared Visitor[ClassInfo] checkInstances;

/// Serialises both the lookup-or-create of `checkInstances` and the
/// downstream `check.visit(...)`. The check classes are *not*
/// thread-safe internally (they accumulate state in plain AAs and
/// arrays), so the whole `visit` runs under the lock. If LDC ever calls
/// the plugin sequentially the lock is uncontended anyway.
///
/// Constructed inside the existing `pragma(crt_constructor)` entry
/// point — that runs reliably during `dlopen`, whereas D-level
/// `shared static this` blocks aren't guaranteed to fire in a plugin.
private __gshared Mutex pluginMutex;


pragma(crt_constructor)
extern(C) void ldclint_initialize()
{
    import std.string : split;
    import std.process : environment;

    options.initialize();

    auto args = environment.get("LDCLINT_FLAGS", null).split();
    options.parse(args);

    pluginMutex = new Mutex;
}

export extern(C) void runSemanticAnalysis(imported!"ldclint.dmd".Module m)
{
    import ldclint.utils.querier : querier;

    auto filename = cast(immutable) m.srcfile.toString();

    if (!options.shouldAnalyze(moduleFqn(m), filename))
        return;

    import ldclint.dparse : dparseModule;
    dparseModule(
        options.isEnabled("parser") ? Yes.parserErrors : No.parserErrors,
        m,
        filename,
    );

    foreach (ref info; allChecks())
    {
        if (!options.isEnabled(info.metadata.fullName)) continue;

        synchronized (pluginMutex)
        {
            Visitor check;
            if (auto existing = info.classInfo in checkInstances)
                check = *existing;
            else
            {
                check = cast(Visitor) info.classInfo.create();
                checkInstances[info.classInfo] = check;
            }

            check.visit(querier(m));
        }
    }
}

private string moduleFqn(imported!"ldclint.dmd".Module m)
{
    import dmd.common.outbuffer : OutBuffer;

    OutBuffer buf;
    m.fullyQualifiedName(buf);
    return cast(immutable)buf.extractSlice();
}
