module ldclint.plugin;

import ldclint.checks;
import ldclint.options;

import std.typecons : Flag, Yes, No;

pragma(crt_constructor)
extern(C) void ldclint_initialize()
{
    import std.string : split;
    import std.process : environment;

    options.initialize();

    auto args = environment.get("LDCLINT_FLAGS", null).split();
    options.parse(args);
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
        if (options.isEnabled(info.metadata.fullName))
        {
            import ldclint.utils.visitor : Visitor;
            auto check = cast(Visitor) info.classInfo.create();
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
