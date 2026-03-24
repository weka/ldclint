module ldclint.checks.empty_block;

import ldclint.utils.querier : Querier, querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons : No, Yes, Flag;

enum Metadata = imported!"ldclint.checks".Metadata(
    "empty-block",
    No.byDefault,
);

final class Check : imported!"ldclint.checks".GenericCheck!Metadata
{
    alias visit = imported!"ldclint.checks".GenericCheck!Metadata.visit;

    override void visit(Querier!(DMD.IfStatement) s)
    {
        if (!s.isValid()) return;

        super.visit(s);

        bool ifEmpty = isEmptyBlock(s.ifbody);
        bool elseEmpty = s.elsebody !is null && isEmptyBlock(s.elsebody);

        if (ifEmpty && s.elsebody !is null && !elseEmpty)
        {
            warning(s.loc, "Empty `if` body with non-empty `else`; consider negating the condition");
        }
        else if (ifEmpty && s.elsebody is null)
        {
            warning(s.loc, "Empty `if` body with no `else`; consider removing the statement");
        }
        else if (elseEmpty)
        {
            warning(s.elsebody.loc, "Empty `else` body; consider removing the `else` clause");
        }
    }

    private static bool isEmptyBlock(DMD.Statement s)
    {
        if (s is null) return true;

        // unwrap ScopeStatement
        if (auto ss = s.isScopeStatement())
            return isEmptyBlock(ss.statement);

        // a CompoundStatement with no statements is an empty { }
        if (auto cs = s.isCompoundStatement())
            return cs.statements is null || (*cs.statements).length == 0;

        return false;
    }

    // avoid false positives inside uninstantiated templates
    override void visit(Querier!(DMD.TemplateDeclaration)) { /* skip */ }
}
