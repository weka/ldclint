module ldclint.checks.builtin_property;

import ldclint.utils.querier : Querier, querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons : No, Yes, Flag;

enum Metadata = imported!"ldclint.checks".Metadata(
    "builtin-property",
    No.byDefault,
);

final class Check : imported!"ldclint.checks".GenericCheck!Metadata
{
    mixin imported!"ldclint.checks".RegisterCheck!Metadata;

    alias visit = imported!"ldclint.checks".GenericCheck!Metadata.visit;

    private static immutable string[] builtinNames = [
        "init", "sizeof", "alignof", "mangleof", "stringof",
    ];

    override void visit(Querier!(DMD.FuncDeclaration) fd)
    {
        if (!fd.isValid()) return;

        checkBuiltinName(fd);

        super.visit(fd);
    }

    override void visit(Querier!(DMD.VarDeclaration) vd)
    {
        if (!vd.isValid()) return;

        checkBuiltinName(vd);

        super.visit(vd);
    }

    private void checkBuiltinName(T)(T decl)
    {
        if (decl.ident is null) return;

        // only warn if inside a struct/class/interface/union
        auto parent = decl.toParent();
        if (parent is null) return;
        if (!parent.isAggregateDeclaration()) return;

        auto name = decl.ident.toString();
        foreach (builtin; builtinNames)
        {
            if (name == builtin)
            {
                warning(decl.loc,
                    "Member `%s` shadows built-in `.%s` property",
                    name.ptr, builtin.ptr);
                return;
            }
        }
    }

    // avoid false positives inside uninstantiated templates
    override void visit(Querier!(DMD.TemplateDeclaration)) { /* skip */ }
}
