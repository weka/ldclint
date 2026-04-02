module ldclint.checks.suspicious_length_subtraction;

import ldclint.utils.querier : Querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons : No, Yes, Flag;

enum Metadata = imported!"ldclint.checks".Metadata(
    "suspicious",
    "length-subtraction",
    No.byDefault,
);

/// Checks for subtracting from .length, which may underflow since it is unsigned.
/// Ported from D-Scanner's length_subtraction check (457fab85a737, https://github.com/dlang-community/D-Scanner).
final class Check : imported!"ldclint.checks".GenericCheck!Metadata
{
    mixin imported!"ldclint.checks".RegisterCheck!Metadata;

    alias visit = imported!"ldclint.checks".GenericCheck!Metadata.visit;

    override void visit(Querier!(DMD.MinExp) e)
    {
        if (!e.isValid()) return;

        super.visit(e);

        if (e.e1 is null) return;

        if (isLengthAccess(e.e1))
            warning(e.loc, "Unsigned subtraction from `.length` may wrap around to `size_t.max`.");
    }

    private static bool isLengthAccess(DMD.Expression expr)
    {
        import std.string : fromStringz, endsWith;

        if (expr is null) return false;

        // Parse-time: DotIdExp with "length"
        if (auto dotId = expr.isDotIdExp())
            return dotId.ident !is null && dotId.ident.toString() == "length";

        // Semantic-time: DotVarExp accessing .length
        if (auto dotVar = expr.isDotVarExp())
            return dotVar.var !is null && dotVar.var.ident !is null
                && dotVar.var.ident.toString() == "length";

        // Semantic-time: CastExp wrapping a length access
        if (auto ce = expr.isCastExp())
            return isLengthAccess(ce.e1);

        // Semantic-time: ArrayLengthExp (resolved .length on arrays)
        // Use toChars() as a fallback to detect .length in resolved expressions
        auto chars = expr.toChars();
        if (chars !is null)
        {
            auto str = fromStringz(chars);
            if (str.endsWith(".length"))
                return true;
        }

        return false;
    }

    // avoid false positives inside uninstantiated templates
    override void visit(Querier!(DMD.TemplateDeclaration)) { /* skip */ }
}
