module ldclint.checks.public_import;

import ldclint.utils.querier : Querier, querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons : No, Yes, Flag;

enum Metadata = imported!"ldclint.checks".Metadata(
    "public-import",
    Yes.byDefault,
);

final class Check : imported!"ldclint.checks".GenericCheck!Metadata
{
    mixin imported!"ldclint.checks".RegisterCheck!Metadata;

    alias visit = imported!"ldclint.checks".GenericCheck!Metadata.visit;

    /// Track VisibilityDeclaration locations to detect block-style public:
    uint publicBlockLine;

    override void visit(Querier!(DMD.VisibilityDeclaration) vd)
    {
        if (!vd.isValid()) return;

        if (vd.visibility.kind == DMD.Visibility.Kind.public_)
        {
            auto prevLine = publicBlockLine;
            publicBlockLine = vd.loc.linnum;
            scope(exit) publicBlockLine = prevLine;
            super.visit(vd);
        }
        else
        {
            super.visit(vd);
        }
    }

    override void visit(Querier!(DMD.Import) imp)
    {
        if (imp.astNode is null) return;

        // skip the implicit object import
        if (imp.id == DMD.Id.object) return;

        // warn if the import is public and on a different line than
        // the visibility declaration (i.e. `public:` block-style)
        if (imp.visibility.kind == DMD.Visibility.Kind.public_ && publicBlockLine > 0)
        {
            // if the VisibilityDeclaration and Import are on different lines,
            // it's a `public:` block. If same line, it's `public import X;`.
            if (imp.loc.linnum != publicBlockLine)
            {
                warning(imp.loc,
                    "Import of `%s` is public via `public:` block; use explicit `public import` for clarity",
                    imp.toChars());
            }
        }
    }

    // avoid false positives inside uninstantiated templates
    override void visit(Querier!(DMD.TemplateDeclaration)) { /* skip */ }
}
