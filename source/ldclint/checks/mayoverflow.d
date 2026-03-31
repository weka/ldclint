module ldclint.checks.mayoverflow;

import ldclint.utils.querier : Querier, querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons : No, Yes, Flag;

enum Metadata = imported!"ldclint.checks".Metadata(
    "mayoverflow",
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

    override void visit(Querier!(DMD.CastExp) e)
    {
        // traverse through the AST
        super.visit(e);

        // lets skip invalid vars
        if (!e.isValid()) return;

        // skip unresolved variables
        if (!e.isResolved()) return;

        if (auto mule = e.e1.isMulExp())
            visitCasted(querier(mule), querier(e.to));
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

    private void visitCasted(Querier!(DMD.MulExp) e, Querier!(DMD.Type) type)
    {
        // lets skip invalid assignments
        if (!e.isValid()) return;

        // don't warn about unresolved expressions
        if (!e.lhs.isResolved() || !e.rhs.isResolved()) return;

        auto lhsType = e.lhs.type.baseType();
        auto rhsType = e.rhs.type.baseType();

        // if they are not scalars, lets skip it
        if (!lhsType.isScalarType.get || !rhsType.isScalarType.get) return;

        if (auto re1 = e.e1.isRealExp())
        {
            auto r1 = re1.toReal();
            if (r1 <= 1.0L && r1 >= -1.0L) return;
        }
        else if (auto ie1 = e.e1.isIntegerExp())
        {
            if (lhsType.isUnsignedType.get)
            {
                ulong u1 = ie1.toUInteger();
                if (u1 <= 1) return;
            }
            else
            {
                long i1 = ie1.toInteger();
                if (i1 <= 1 && i1 >= -1) return;
            }
        }

        if (auto re2 = e.e2.isRealExp())
        {
            auto r2 = re2.toReal();
            if (r2 <= 1.0L && r2 >= -1.0L) return;
        }
        else if (auto ie2 = e.e2.isIntegerExp())
        {
            if (rhsType.isUnsignedType.get)
            {
                ulong u2 = ie2.toUInteger();
                if (u2 <= 1) return;
            }
            else
            {
                long i2 = ie2.toInteger();
                if (i2 <= 1 && i2 >= -1) return;
            }
        }

        auto s1 = lhsType.size().get;
        auto s2 = rhsType.size().get;

        auto castSize = type.size().get;

        if (s1 < castSize && s2 < castSize)
        {
            warning(e.loc, "Expression `%s` may overflow before conversion", e.toChars());
        }
    }
}
