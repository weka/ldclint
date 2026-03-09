module ldclint.checks.coherence;

import ldclint.utils.querier : Querier, querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons : No, Yes, Flag;

enum Metadata = imported!"ldclint.checks".Metadata(
    "coherence",
    Yes.byDefault,
);

final class Check : imported!"ldclint.checks".GenericCheck!Metadata
{
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

            case DMD.Tstruct:
                auto ts = t.astNode.isTypeStruct();
                if (!ts)
                {
                    error(DMD.Loc.initial, "Type `%s` is not coherent with it's type class", t.toChars());
                }
                break;

            case DMD.Terror:
                error(DMD.Loc.initial, "Type `%s` resolves to an error type", t.toChars());
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
