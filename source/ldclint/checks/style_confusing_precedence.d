module ldclint.checks.style_confusing_precedence;

import ldclint.utils.querier : Querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons : No, Yes, Flag;

enum Metadata = imported!"ldclint.checks".Metadata(
    "style",
    "confusing-precedence",
    No.byDefault,
);

/// Checks for confusing && and || operator precedence without parentheses.
/// Ported from D-Scanner's logic_precedence check (457fab85a737, https://github.com/dlang-community/D-Scanner).
final class Check : imported!"ldclint.checks".GenericCheck!Metadata
{
    mixin imported!"ldclint.checks".RegisterCheck!Metadata;

    alias visit = imported!"ldclint.checks".GenericCheck!Metadata.visit;

    override void visit(Querier!(DMD.LogicalExp) le)
    {
        if (!le.isValid()) return;

        super.visit(le);

        // Only check || expressions
        if (le.op != DMD.EXP.orOr) return;

        auto left = le.e1 ? le.e1.isLogicalExp() : null;
        auto right = le.e2 ? le.e2.isLogicalExp() : null;

        // Check if either side is an && expression
        bool leftIsAnd = left !is null && left.op == DMD.EXP.andAnd;
        bool rightIsAnd = right !is null && right.op == DMD.EXP.andAnd;

        if (!leftIsAnd && !rightIsAnd) return;

        // Don't warn if the && expression is parenthesized
        if ((leftIsAnd && left.parens) || (rightIsAnd && right.parens)) return;

        // Skip incomplete expressions
        if ((left !is null && left.e2 is null) && (right !is null && right.e2 is null)) return;

        warning(le.loc, "Use parentheses to clarify `&&` and `||` precedence");
    }

    // avoid false positives inside uninstantiated templates
    override void visit(Querier!(DMD.TemplateDeclaration)) { /* skip */ }
}
