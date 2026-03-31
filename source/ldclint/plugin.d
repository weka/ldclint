module ldclint.plugin;

import ldclint.checks;

import std.typecons : Flag, Yes, No;

struct Options
{
    private bool[string] enabled;
    private bool initialized;

    private void initialize()
    {
        if (initialized) return;
        initialized = true;

        foreach (ref info; allChecks())
            enabled[info.metadata.name] = info.metadata.byDefault == Yes.byDefault;
    }

    bool isEnabled(string name)
    {
        initialize();
        if (auto p = name in enabled)
            return *p;
        return false;
    }

    void parse(string[] args)
    {
        import std.string : strip;

        initialize();

        foreach (arg; args)
        {
            auto a = arg.strip();

            if (a == "-Wall")
            {
                foreach (key; enabled.keys)
                    enabled[key] = true;
            }
            else if (a == "-Wno-all")
            {
                foreach (key; enabled.keys)
                    enabled[key] = false;
            }
            else if (a.length > 5 && a[0 .. 5] == "-Wno-")
            {
                auto name = a[5 .. $];
                if (name in enabled)
                    enabled[name] = false;
            }
            else if (a.length > 2 && a[0 .. 2] == "-W")
            {
                auto name = a[2 .. $];
                if (name in enabled)
                    enabled[name] = true;
            }
        }
    }
}

__gshared Options options;

pragma(crt_constructor)
extern(C) void ldclint_initialize()
{
    import std.string : split;
    import std.process : environment;

    auto args = environment.get("LDCLINT_FLAGS", null).split();
    options.parse(args);
}

export extern(C) void runSemanticAnalysis(imported!"ldclint.dmd".Module m)
{
    import ldclint.utils.querier : querier;

    auto filename = cast(immutable) m.srcfile.toString();

    import ldclint.dparse : dparseModule;
    dparseModule(
        options.isEnabled("parser") ? Yes.parserErrors : No.parserErrors,
        m,
        filename,
    );

    foreach (ref info; allChecks())
    {
        if (options.isEnabled(info.metadata.name))
        {
            auto check = cast(AbstractCheck) info.classInfo.create();
            check.visit(querier(m));
        }
    }
}
