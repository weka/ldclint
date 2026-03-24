module ldclint.checks.negate_unsigned;

import ldclint.utils.querier : Querier, querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons : No, Yes, Flag;

enum Metadata = imported!"ldclint.checks".Metadata(
    "negate-unsigned",
    No.byDefault,
);

final class Check : imported!"ldclint.checks".GenericCheck!Metadata
{
    alias visit = imported!"ldclint.checks".GenericCheck!Metadata.visit;

    override void visit(Querier!(DMD.NegExp) e)
    {
        super.visit(e);

        if (!e.isValid()) return;
        if (!e.isResolved) return;

        auto inner = cast(DMD.Expression)e.e1;
        if (inner is null || inner.type is null) return;

        auto bt = inner.type.toBasetype();
        if (bt is null) return;

        if (isUnsignedIntegerType(bt))
        {
            // skip compile-time literals (e.g. -1u is a common pattern)
            if (inner.isIntegerExp()) return;

            warning(e.loc, "Negating unsigned integer of type `%s`", bt.toChars());
        }
    }

    private static bool isUnsignedIntegerType(DMD.Type t)
    {
        switch (t.ty)
        {
            case DMD.Tuns8:
            case DMD.Tuns16:
            case DMD.Tuns32:
            case DMD.Tuns64:
                return true;
            default:
                return false;
        }
    }

    // avoid false positives inside uninstantiated templates
    override void visit(Querier!(DMD.TemplateDeclaration)) { /* skip */ }
}
