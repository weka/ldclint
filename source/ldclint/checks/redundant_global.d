module ldclint.checks.redundant_global;

import ldclint.utils.querier : Querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons : No, Yes, Flag;

enum Metadata = imported!"ldclint.checks".Metadata(
    "redundant",
    "global",
    Yes.byDefault,
);

final class Check : imported!"ldclint.checks".GenericCheck!Metadata
{
    mixin imported!"ldclint.checks".RegisterCheck!Metadata;

    alias visit = imported!"ldclint.checks".GenericCheck!Metadata.visit;

    // true when inside a StorageClassDeclaration block that contains non-variable members
    // (functions or aggregates) where `static` has a distinct meaning; variables in the
    // same block inherit the combination but it is not redundant there.
    bool inRelevantBlock;

    override void visit(Querier!(DMD.StorageClassDeclaration) scd)
    {
        if (!scd.isValid()) return;

        auto prev = inRelevantBlock;
        if (scd.stc & (DMD.STC.static_ | DMD.STC.gshared) && scd.decl)
        {
            foreach (sym; *scd.decl)
            {
                if (sym.isFuncDeclaration() || sym.isAggregateDeclaration())
                {
                    inRelevantBlock = true;
                    break;
                }
            }
        }
        scope(exit) inRelevantBlock = prev;

        super.visit(scd);
    }

    override void visit(Querier!(DMD.VarDeclaration) vd)
    {
        // lets skip invalid variable declarations
        if (!vd.isValid()) return;

        if (!inRelevantBlock &&
            vd.storage_class & DMD.STC.static_ && vd.storage_class & DMD.STC.gshared)
            warning(vd.loc, "Redundant attribute `static` and `__gshared`");

        // traverse through the AST
        super.visit(vd);
    }

    // avoid all sorts of false positives without semantics
    override void visit(Querier!(DMD.TemplateDeclaration) /* td */) { /* skip */ }
}
