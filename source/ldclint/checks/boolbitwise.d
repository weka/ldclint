module ldclint.checks.boolbitwise;

import ldclint.utils.querier : Querier, querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons : No, Yes, Flag;

enum Metadata = imported!"ldclint.checks".Metadata(
    "boolbitwise",
    Yes.byDefault,
);

final class Check : imported!"ldclint.checks".GenericCheck!Metadata
{
    alias visit = imported!"ldclint.checks".GenericCheck!Metadata.visit;

    override void visit(Querier!(DMD.AndExp) e) { visitBinExp(e); }
    override void visit(Querier!(DMD.OrExp) e)  { visitBinExp(e); }
    override void visit(Querier!(DMD.ComExp) e) { visitUnaExp(e); }

    private void visitBinExp(E)(E e)
    {
        super.visit(e);

        if (!e.isValid()) return;
        if (!e.isResolved) return;

        visitExp(e.e1);
        visitExp(e.e2);
    }

    private void visitUnaExp(E)(E e)
    {
        super.visit(e);

        if (!e.isValid()) return;
        if (!e.isResolved) return;

        visitExp(e.e1);
    }

    private void visitExp(DMD.Expression e)
    {
        if (e is null) return;

        auto t = e.type;
        if (!t) return;

        if (t.toBasetype().ty == DMD.Tbool)
        {
            warning(e.loc, "Avoid bitwise operations with boolean `%s`", e.toChars());
        }
    }

    // avoid all sorts of false positives without semantics
    override void visit(Querier!(DMD.TemplateDeclaration)) { /* skip */ }
}
