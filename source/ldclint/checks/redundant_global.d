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

    override void visit(Querier!(DMD.VarDeclaration) vd)
    {
        // lets skip invalid variable declarations
        if (!vd.isValid()) return;

        if (vd.storage_class & DMD.STC.static_ && vd.storage_class & DMD.STC.gshared)
            warning(vd.loc, "Redundant attribute `static` and `__gshared`");

        // traverse through the AST
        super.visit(vd);
    }

    // avoid all sorts of false positives without semantics
    override void visit(Querier!(DMD.TemplateDeclaration) /* td */) { /* skip */ }
}
