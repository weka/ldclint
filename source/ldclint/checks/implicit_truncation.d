module ldclint.checks.implicit_truncation;

import ldclint.utils.querier : Querier, querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons : No, Yes, Flag;

enum Metadata = imported!"ldclint.checks".Metadata(
    "implicit",
    "truncation",
    No.byDefault,
);

final class Check : imported!"ldclint.checks".GenericCheck!Metadata
{
    mixin imported!"ldclint.checks".RegisterCheck!Metadata;

    alias visit = imported!"ldclint.checks".GenericCheck!Metadata.visit;

    override void visit(Querier!(DMD.CastExp) e)
    {
        super.visit(e);

        if (!e.isValid()) return;
        if (!e.isResolved()) return;

        // check if casting to a floating-point type
        auto castType = e.type;
        if (castType is null) return;
        auto castBase = castType.toBasetype();
        if (!isFloatType(castBase)) return;

        // check if the inner expression is integer division or modulo
        auto inner = cast(DMD.Expression)e.e1;
        if (inner is null) return;

        if (auto divExp = inner.isDivExp())
            checkIntegerDivision(e.loc, divExp);
        else if (auto modExp = inner.isModExp())
            checkIntegerDivision(e.loc, modExp);
    }

    private void checkIntegerDivision(E)(DMD.Loc loc, E binExp)
    {
        if (binExp.e1 is null || binExp.e2 is null) return;
        if (binExp.e1.type is null || binExp.e2.type is null) return;

        auto t1 = binExp.e1.type.toBasetype();
        auto t2 = binExp.e2.type.toBasetype();

        // both operands must be integer types
        if (!isIntegerType(t1) || !isIntegerType(t2)) return;

        warning(loc,
            "Integer division cast to floating-point; division truncates before conversion. "
            ~ "Cast an operand before dividing: `%s`",
            binExp.toChars());
    }

    private static bool isFloatType(DMD.Type t)
    {
        switch (t.ty)
        {
            case DMD.Tfloat32:
            case DMD.Tfloat64:
            case DMD.Tfloat80:
                return true;
            default:
                return false;
        }
    }

    private static bool isIntegerType(DMD.Type t)
    {
        switch (t.ty)
        {
            case DMD.Tint8:
            case DMD.Tint16:
            case DMD.Tint32:
            case DMD.Tint64:
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
