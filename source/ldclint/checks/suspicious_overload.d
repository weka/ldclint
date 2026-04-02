module ldclint.checks.suspicious_overload;

import ldclint.utils.querier : Querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons : No, Yes, Flag;

enum Metadata = imported!"ldclint.checks".Metadata(
    "suspicious",
    "overload",
    No.byDefault,
);

/// Checks that classes/structs with opEquals also have toHash, and vice versa.
/// Ported from D-Scanner's opequals_without_tohash check (457fab85a737, https://github.com/dlang-community/D-Scanner).
final class Check : imported!"ldclint.checks".GenericCheck!Metadata
{
    mixin imported!"ldclint.checks".RegisterCheck!Metadata;

    alias visit = imported!"ldclint.checks".GenericCheck!Metadata.visit;

    override void visit(Querier!(DMD.ClassDeclaration) d)
    {
        if (!d.isValid()) return;

        checkAggregate(d);
        super.visit(d);
    }

    override void visit(Querier!(DMD.StructDeclaration) d)
    {
        if (!d.isValid()) return;

        checkAggregate(d);
        super.visit(d);
    }

    private void checkAggregate(T)(T ad)
    {
        if (ad.members is null) return;

        bool hasOpEquals, hasToHash;

        foreach (member; *ad.members)
        {
            if (auto fd = member.isFuncDeclaration())
                checkFunc(fd, hasOpEquals, hasToHash);
            else if (auto scd = member.isStorageClassDeclaration())
            {
                if (scd.decl)
                    foreach (smember; *scd.decl)
                        if (auto fd = smember.isFuncDeclaration())
                            checkFunc(fd, hasOpEquals, hasToHash);
            }
        }

        if (hasOpEquals && !hasToHash)
            warning(ad.loc, "`%s` defines `opEquals` without a matching `toHash`; define both for correct hash-based container behavior.", ad.toChars());
        else if (!hasOpEquals && hasToHash)
            warning(ad.loc, "`%s` defines `toHash` without a matching `opEquals`; define both for correct hash-based container behavior.", ad.toChars());
    }

    private static void checkFunc(DMD.FuncDeclaration fd, ref bool hasOpEquals, ref bool hasToHash)
    {
        if (fd.storage_class & DMD.STC.disable) return;

        auto name = fd.ident.toString();
        if (name == "opEquals") hasOpEquals = true;
        if (name == "toHash") hasToHash = true;
    }

    // avoid false positives inside uninstantiated templates
    override void visit(Querier!(DMD.TemplateDeclaration)) { /* skip */ }
}
