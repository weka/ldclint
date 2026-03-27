module ldclint.checks.redundant;

import ldclint.utils.querier : Querier, querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.stdio;
import std.string;
import std.array;
import std.range;
import std.bitmanip;

enum Metadata = imported!"ldclint.checks".Metadata(
    "redundant",
    Yes.byDefault,
);

final class Check : imported!"ldclint.checks".GenericCheck!Metadata
{
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

    override void visit(Querier!(DMD.FuncDeclaration) fd)
    {
        // lets skip invalid function declarations
        if (!fd.isValid()) return;

        if (fd.storage_class & DMD.STC.final_ && fd.visibility.kind == DMD.Visibility.Kind.private_)
            warning(fd.loc, "Redundant attribute `final` with `private` visibility");

        // traverse through the AST
        super.visit(fd);
    }

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

            // skip rvalues from this check
            if (!querier(e.e1).isLvalue.get) return;
            if (!querier(e.e2).isLvalue.get) return;

            warning(e.loc, "Redundant expression `%s`", e.toChars());
        }
    }

    override void visit(Querier!(DMD.IfStatement) s)
    {
        if (!s.isValid()) return;

        super.visit(s);

        bool bodyEmpty = s.body.isEmpty();

        if (auto es = s.elseBody())
        {
            if (es.isEmpty())
            {
                if (!hasCommentInBlock(s.elsebody.loc))
                    warning(s.elsebody.loc, "Empty `else` body; consider removing the `else` clause");
            }
            else if (bodyEmpty)
            {
                if (!hasCommentInBlock(s.loc))
                    warning(s.loc, "Empty `if` body with non-empty `else`; consider negating the condition");
            }
            else return;
        }

        if (bodyEmpty)
        {
            if (!hasCommentInBlock(s.loc))
                warning(s.loc, "Empty `if` body with no `else`; consider removing the statement");
        }
    }

    /// Check if the source text between { } at the given loc contains a comment.
    /// Since the compiler strips comments from the AST, we scan the raw source.
    private bool hasCommentInBlock(DMD.Loc loc)
    {
        if (currentModule is null) return false;
        auto src = cast(const(char)[]) currentModule.src;
        if (src.length == 0) return false;

        // Find byte offset for the start of the loc's line
        size_t offset = 0;
        for (uint line = 1; offset < src.length && line < loc.linnum; offset++)
            if (src[offset] == '\n')
                line++;

        // Advance by column to avoid matching braces before the block
        offset += loc.charnum;

        // Find opening brace
        while (offset < src.length && src[offset] != '{')
            offset++;
        if (offset >= src.length) return false;
        offset++;

        // Scan between { and matching } for comment markers
        for (int depth = 1; offset < src.length && depth > 0; offset++)
        {
            if (src[offset] == '{') depth++;
            else if (src[offset] == '}') depth--;
            else if (src[offset] == '/' && offset + 1 < src.length
                && (src[offset + 1] == '/' || src[offset + 1] == '*'))
                return true;
        }

        return false;
    }

    // avoid all sorts of false positives without semantics
    override void visit(Querier!(DMD.TemplateDeclaration) /* td */) { /* skip */ }
}
