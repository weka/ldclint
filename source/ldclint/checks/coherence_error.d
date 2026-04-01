module ldclint.checks.coherence_error;

import ldclint.utils.querier : Querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons : No, Yes, Flag;

enum Metadata = imported!"ldclint.checks".Metadata(
    "coherence",
    "error",
    Yes.byDefault,
);

final class Check : imported!"ldclint.checks".GenericCheck!Metadata
{
    mixin imported!"ldclint.checks".RegisterCheck!Metadata;

    alias visit = imported!"ldclint.checks".GenericCheck!Metadata.visit;

    override void visit(Querier!(DMD.Type) t)
    {
        // lets skip invalid types
        if (!t.isValid()) return;

        if (t.astNode.ty == DMD.Terror)
        {
            error(DMD.Loc.initial, "Type `%s` resolves to an error type", t.toChars());
        }

        // traverse through the AST
        super.visit(t);
    }

    // avoid all sorts of false positives without semantics
    override void visit(Querier!(DMD.TemplateDeclaration)) { /* skip */ }
}
