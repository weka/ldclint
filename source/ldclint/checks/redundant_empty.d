module ldclint.checks.redundant_empty;

import ldclint.utils.querier : Querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons : No, Yes, Flag;

enum Metadata = imported!"ldclint.checks".Metadata(
    "redundant",
    "empty",
    Yes.byDefault,
);

final class Check : imported!"ldclint.checks".GenericCheck!Metadata
{
    mixin imported!"ldclint.checks".RegisterCheck!Metadata;

    alias visit = imported!"ldclint.checks".GenericCheck!Metadata.visit;

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
