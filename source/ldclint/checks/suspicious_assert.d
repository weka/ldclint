module ldclint.checks.suspicious_assert;

import ldclint.utils.querier : Querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons : No, Yes, Flag;

enum Metadata = imported!"ldclint.checks".Metadata(
    "suspicious",
    "assert",
    No.byDefault,
);

/// Checks for asserts with conditions that are always true.
/// Ported from D-Scanner's useless_assert check (457fab85a737, https://github.com/dlang-community/D-Scanner).
final class Check : imported!"ldclint.checks".GenericCheck!Metadata
{
    mixin imported!"ldclint.checks".RegisterCheck!Metadata;

    alias visit = imported!"ldclint.checks".GenericCheck!Metadata.visit;

    override void visit(Querier!(DMD.AssertExp) e)
    {
        if (!e.isValid()) return;

        super.visit(e);

        if (e.e1 is null) return;

        // Non-zero integer literal (assert(1), assert(true))
        if (auto ie = e.e1.isIntegerExp())
        {
            if (ie.getInteger() != 0)
                warning(e.loc, "Assert condition is a compile-time constant and is always true; did you mean to assert a variable?");
            return;
        }

        // Non-zero real literal (assert(3.14))
        if (auto re = e.e1.isRealExp())
        {
            if (re.value != 0)
                warning(e.loc, "Assert condition is a compile-time constant and is always true; did you mean to assert a variable?");
            return;
        }

        // String, array, or associative array literals are always truthy
        if (e.e1.isStringExp() || e.e1.isArrayLiteralExp() || e.e1.isAssocArrayLiteralExp())
            warning(e.loc, "Assert condition is a compile-time constant and is always true; did you mean to assert a variable?");
    }

    // avoid false positives inside uninstantiated templates
    override void visit(Querier!(DMD.TemplateDeclaration)) { /* skip */ }
}
