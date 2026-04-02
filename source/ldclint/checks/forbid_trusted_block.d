module ldclint.checks.forbid_trusted_block;

import ldclint.utils.querier : Querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons : No, Yes, Flag;

enum Metadata = imported!"ldclint.checks".Metadata(
    "forbid",
    "trusted-block",
    No.byDefault,
);

/// Checks that @trusted is only applied to individual functions, not whole scopes.
/// Ported from D-Scanner's trust_too_much check (457fab85a737, https://github.com/dlang-community/D-Scanner).
final class Check : imported!"ldclint.checks".GenericCheck!Metadata
{
    mixin imported!"ldclint.checks".RegisterCheck!Metadata;

    alias visit = imported!"ldclint.checks".GenericCheck!Metadata.visit;

    override void visit(Querier!(DMD.StorageClassDeclaration) scd)
    {
        if (!scd.isValid()) return;

        if (scd.stc & DMD.STC.trusted)
            warning(scd.loc, "Avoid `@trusted` blocks; mark individual functions `@trusted` instead.");

        super.visit(scd);
    }

    // avoid false positives inside uninstantiated templates
    override void visit(Querier!(DMD.TemplateDeclaration)) { /* skip */ }
}
