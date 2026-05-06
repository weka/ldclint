module ldclint.checks.redundant_expression;

import ldclint.utils.querier : Querier, querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons : No, Yes, Flag;

enum Metadata = imported!"ldclint.checks".Metadata(
    "redundant",
    "expression",
    Yes.byDefault,
);

final class Check : imported!"ldclint.checks".GenericCheck!Metadata
{
    mixin imported!"ldclint.checks".RegisterCheck!Metadata;

    alias visit = imported!"ldclint.checks".GenericCheck!Metadata.visit;

    override void visit(Querier!(DMD.IdentityExp) e) { visitBinExp(e); }
    override void visit(Querier!(DMD.EqualExp) e)    { visitBinExp(e); }
    override void visit(Querier!(DMD.CmpExp) e)      { visitBinExp(e); }
    override void visit(Querier!(DMD.AssignExp) e)   { visitBinExp(e); }
    override void visit(Querier!(DMD.LogicalExp) e)  { visitBinExp(e); }
    override void visit(Querier!(DMD.AndExp) e)      { visitBinExp(e); }
    override void visit(Querier!(DMD.OrExp) e)       { visitBinExp(e); }
    override void visit(Querier!(DMD.MinExp) e)      { visitBinExp(e); }
    override void visit(Querier!(DMD.XorExp) e)      { visitBinExp(e); }

    private void visitBinExp(E)(E e)
    {
        super.visit(e);

        // lets skip invalid expressions
        if (!e.isValid()) return;

        // skip unresolved expressions
        if (!e.isResolved) return;

        if (querier(e.e1).isIdentical(e.e2))
        {
            // skip expressions known at compile-time
            if (querier(e.e1).hasCTKnownValue.get || querier(e.e2).hasCTKnownValue.get) return;

            // Skip everything that isn't a plain variable / member / index
            // reference. Using op-kind here (rather than `isLvalue`) avoids
            // the D 2.112 rvalue-flag regression where VarExp.isLvalue can
            // return false for normal identifier reads.
            if (!isStructuralLvalue(e.e1) || !isStructuralLvalue(e.e2)) return;

            warning(e.loc, "Redundant expression `%s`", e.toChars());
        }
    }

    private static bool isStructuralLvalue(DMD.Expression e)
    {
        switch (e.op)
        {
            case DMD.EXP.variable:
            case DMD.EXP.dotVariable:
            case DMD.EXP.index:
                return true;
            default:
                return false;
        }
    }

    // avoid all sorts of false positives without semantics
    override void visit(Querier!(DMD.TemplateDeclaration) /* td */) { /* skip */ }
}
