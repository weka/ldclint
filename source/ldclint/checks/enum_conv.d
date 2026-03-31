module ldclint.checks.enum_conv;

import ldclint.utils.querier : Querier, querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons : No, Yes, Flag;

enum Metadata = imported!"ldclint.checks".Metadata(
    "enum-conv",
    No.byDefault,
);

final class Check : imported!"ldclint.checks".GenericCheck!Metadata
{
    mixin imported!"ldclint.checks".RegisterCheck!Metadata;

    alias visit = imported!"ldclint.checks".GenericCheck!Metadata.visit;

    override void visit(Querier!(DMD.CondExp) e)
    {
        super.visit(e);

        if (!e.isValid()) return;
        if (!e.isResolved()) return;

        auto t1 = getEnumType(cast(DMD.Expression) e.e1);
        auto t2 = getEnumType(cast(DMD.Expression) e.e2);

        if (t1 is null || t2 is null) return;
        if (t1.sym is t2.sym) return;

        warning(e.loc,
            "Implicit conversion merges different enum types `%s` and `%s`",
            t1.sym.toChars(), t2.sym.toChars());
    }

    private static DMD.TypeEnum getEnumType(DMD.Expression e)
    {
        if (e is null) return null;

        auto t = e.type;
        if (t is null) return null;

        if (auto te = t.isTypeEnum())
            return te;

        // If typeMerge already lowered, unwrap CastExp to get original type
        if (auto ce = e.isCastExp())
            return getEnumType(ce.e1);

        return null;
    }

    // avoid false positives inside uninstantiated templates
    override void visit(Querier!(DMD.TemplateDeclaration)) { /* skip */ }
}
