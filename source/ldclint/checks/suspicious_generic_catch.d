module ldclint.checks.suspicious_generic_catch;

import ldclint.utils.querier : Querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons : No, Yes, Flag;

enum Metadata = imported!"ldclint.checks".Metadata(
    "suspicious",
    "generic-catch",
    No.byDefault,
);

/// Checks for catching Error or Throwable, which is almost always a bad idea.
/// Ported from D-Scanner's pokemon exception check (457fab85a737, https://github.com/dlang-community/D-Scanner).
final class Check : imported!"ldclint.checks".GenericCheck!Metadata
{
    mixin imported!"ldclint.checks".RegisterCheck!Metadata;

    alias visit = imported!"ldclint.checks".GenericCheck!Metadata.visit;

    override void visit(Querier!(DMD.Catch) c)
    {
        if (!c.isValid()) return;

        super.visit(c);

        if (c.astNode.type is null) return;

        // After semantic analysis, the type is resolved to TypeClass
        auto bt = c.astNode.type.toBasetype();
        if (bt is null) return;

        auto cd = bt.isClassHandle();
        if (cd is null) return;

        auto name = cd.ident.toString();
        if (name == "Error" || name == "Throwable")
            warning(c.loc, "Catching a non-exception throwable `%s`.", name.ptr);
    }

    // avoid false positives inside uninstantiated templates
    override void visit(Querier!(DMD.TemplateDeclaration)) { /* skip */ }
}
