module ldclint.checks.redundant_final;

import ldclint.utils.querier : Querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons : No, Yes, Flag;

enum Metadata = imported!"ldclint.checks".Metadata(
    "redundant",
    "final",
    Yes.byDefault,
);

final class Check : imported!"ldclint.checks".GenericCheck!Metadata
{
    mixin imported!"ldclint.checks".RegisterCheck!Metadata;

    alias visit = imported!"ldclint.checks".GenericCheck!Metadata.visit;

    override void visit(Querier!(DMD.FuncDeclaration) fd)
    {
        // lets skip invalid function declarations
        if (!fd.isValid()) return;

        if (fd.storage_class & DMD.STC.final_ && fd.visibility.kind == DMD.Visibility.Kind.private_)
            warning(fd.loc, "Redundant attribute `final` with `private` visibility");

        // traverse through the AST
        super.visit(fd);
    }

    // avoid all sorts of false positives without semantics
    override void visit(Querier!(DMD.TemplateDeclaration) /* td */) { /* skip */ }
}
