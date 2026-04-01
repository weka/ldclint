module ldclint.checks.implicit_enum_ternary;

import ldclint.utils.querier : Querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons : No, Yes, Flag;

enum Metadata = imported!"ldclint.checks".Metadata(
    "implicit",
    "enum-ternary",
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

        auto t1 = getOriginalType(cast(DMD.Expression) e.e1);
        auto t2 = getOriginalType(cast(DMD.Expression) e.e2);

        if (t1 is null || t2 is null) return;

        // At least one must be an enum
        auto te1 = t1.isTypeEnum();
        auto te2 = t2.isTypeEnum();
        if (te1 is null && te2 is null) return;

        // Same enum type is fine
        if (te1 !is null && te2 !is null && te1.sym is te2.sym) return;

        warning(e.loc,
            "Implicit conversion merges different types `%s` and `%s`",
            t1.toChars(), t2.toChars());
    }

    /// Get the original type of an expression, unwrapping implicit CastExp
    /// inserted by typeMerge to recover the pre-conversion type.
    private static DMD.Type getOriginalType(DMD.Expression e)
    {
        if (e is null) return null;

        // If typeMerge already lowered, unwrap CastExp to get original type
        if (auto ce = e.isCastExp())
        {
            auto inner = getOriginalType(ce.e1);
            if (inner !is null) return inner;
        }

        return e.type;
    }

    // avoid false positives inside uninstantiated templates
    override void visit(Querier!(DMD.TemplateDeclaration)) { /* skip */ }
}
