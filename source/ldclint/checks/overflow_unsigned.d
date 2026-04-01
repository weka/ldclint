module ldclint.checks.overflow_unsigned;

import ldclint.utils.querier : Querier, querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons : No, Yes, Flag;

enum Metadata = imported!"ldclint.checks".Metadata(
    "overflow",
    "unsigned",
    Yes.byDefault,
);

final class Check : imported!"ldclint.checks".GenericCheck!Metadata
{
    mixin imported!"ldclint.checks".RegisterCheck!Metadata;

    alias visit = imported!"ldclint.checks".GenericCheck!Metadata.visit;

    private uint insideAndNegPattern;

    override void visit(Querier!(DMD.AndExp) e)
    {
        // Detect var & -var or -var & var pattern (isolate lowest set bit)
        bool matched;

        if (auto neg = e.e2.isNegExp())
        {
            if (auto v1 = e.e1.isVarExp())
                if (auto v2 = neg.e1.isVarExp())
                    matched = v1.var is v2.var;
        }
        else if (auto neg = e.e1.isNegExp())
        {
            if (auto v1 = e.e2.isVarExp())
                if (auto v2 = neg.e1.isVarExp())
                    matched = v1.var is v2.var;
        }

        if (matched)
            insideAndNegPattern++;

        super.visit(e);

        if (matched)
            insideAndNegPattern--;
    }

    override void visit(Querier!(DMD.NegExp) e)
    {
        // traverse through the AST
        super.visit(e);

        // lets skip invalid vars
        if (!e.isValid()) return;

        // skip unresolved variables
        if (!e.isResolved) return;

        // skip invalid inner expressions
        if (!e.inner.isValid()) return;
        // skip inner expressions with invalid types
        if (!e.inner.type.isValid()) return;

        auto bt = e.inner.type.baseType();
        if (!bt.isValid()) return;

        auto isUnsigned = bt.isUnsignedType();
        if (!isUnsigned.resolved) return;

        if (isUnsigned.get)
        {
            // skip compile-time literals (e.g. -1u is a common pattern)
            if (e.inner.isIntegerExp()) return;

            // skip var & -var pattern (bit manipulation: isolate lowest set bit)
            if (insideAndNegPattern > 0) return;

            warning(e.loc, "Negating unsigned integer of type `%s`: replace `-%s` with `(~%s) + 1`",
                bt.toChars(), e.inner.toChars(), e.inner.toChars());
        }
    }
}
