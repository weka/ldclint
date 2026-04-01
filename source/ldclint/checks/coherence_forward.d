module ldclint.checks.coherence_forward;

import ldclint.utils.querier : Querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons : No, Yes, Flag;

enum Metadata = imported!"ldclint.checks".Metadata(
    "coherence",
    "forward",
    Yes.byDefault,
);

final class Check : imported!"ldclint.checks".GenericCheck!Metadata
{
    mixin imported!"ldclint.checks".RegisterCheck!Metadata;

    alias visit = imported!"ldclint.checks".GenericCheck!Metadata.visit;

    override void visit(Querier!(DMD.Dsymbol) sym)
    {
        // lets skip invalid symbols
        if (!sym.isValid()) return;

        if (sym.isforwardRef())
        {
            warning(sym.loc, "This symbol can't be resolved because it's a forward reference");
        }

        if (auto fd = sym.isFuncDeclaration())
        {
            if (fd.resolvedLinkage() == DMD.LINK.default_)
            {
                warning(fd.loc, "Forward reference on resolving linkage");
            }
        }

        // traverse through the AST
        super.visit(sym);
    }

    override void visit(Querier!(DMD.Type) t)
    {
        // lets skip invalid types
        if (!t.isValid()) return;

        switch (t.astNode.ty)
        {
            case DMD.Tident:
            case DMD.TY.Ttypeof:
            case DMD.TY.Tmixin:
                warning(DMD.Loc.initial, "Type `%s` is a forward reference", t.toChars());
                break;

            default:
                break;
        }

        // traverse through the AST
        super.visit(t);
    }

    // avoid all sorts of false positives without semantics
    override void visit(Querier!(DMD.TemplateDeclaration)) { /* skip */ }
}
