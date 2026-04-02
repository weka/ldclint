module ldclint.checks.style_duplicate_ctor;

import ldclint.utils.querier : Querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons : No, Yes, Flag;

enum Metadata = imported!"ldclint.checks".Metadata(
    "style",
    "duplicate-ctor",
    No.byDefault,
);

/// Checks for classes with both a zero-argument constructor and a constructor
/// where all parameters have default arguments. This can be confusing.
/// Ported from D-Scanner's constructors check (457fab85a737, https://github.com/dlang-community/D-Scanner).
final class Check : imported!"ldclint.checks".GenericCheck!Metadata
{
    mixin imported!"ldclint.checks".RegisterCheck!Metadata;

    alias visit = imported!"ldclint.checks".GenericCheck!Metadata.visit;

    override void visit(Querier!(DMD.ClassDeclaration) d)
    {
        if (!d.isValid()) return;

        if (d.members)
        {
            bool hasNoArgCtor, hasAllDefaultArgCtor;

            foreach (s; *d.members)
            {
                if (auto cd = s.isCtorDeclaration())
                {
                    if (cd.type is null) continue;
                    auto tf = cd.type.isTypeFunction();
                    if (tf is null) continue;

                    auto params = tf.parameterList.parameters;
                    if (params is null || (*params).length == 0)
                    {
                        hasNoArgCtor = true;
                    }
                    else
                    {
                        bool allDefaults = true;
                        foreach (param; *params)
                            if (param.defaultArg is null)
                                allDefaults = false;

                        if (allDefaults)
                            hasAllDefaultArgCtor = true;
                    }
                }
            }

            if (hasNoArgCtor && hasAllDefaultArgCtor)
                warning(d.loc,
                    "Class has both a zero-argument constructor and a constructor "
                    ~ "with all default arguments, which is confusing");
        }

        super.visit(d);
    }

    // avoid false positives inside uninstantiated templates
    override void visit(Querier!(DMD.TemplateDeclaration)) { /* skip */ }
}
