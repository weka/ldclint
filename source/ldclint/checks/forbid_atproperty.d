module ldclint.checks.forbid_atproperty;

import ldclint.utils.querier : Querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons : No, Yes, Flag;

enum Metadata = imported!"ldclint.checks".Metadata(
    "forbid",
    "atproperty",
    No.byDefault,
);

final class Check : imported!"ldclint.checks".GenericCheck!Metadata
{
    mixin imported!"ldclint.checks".RegisterCheck!Metadata;

    alias visit = imported!"ldclint.checks".GenericCheck!Metadata.visit;

    override void visit(Querier!(DMD.FuncDeclaration) fd)
    {
        // lets skip invalid/unresolved functions
        if (!fd.isResolved) return;

        // dmd.TypeFunction renamed isproperty -> isProperty in D 2.111 (LDC 1.41).
        static if (__VERSION__ >= 2111)
            const isAtProperty = fd.type.isTypeFunction().isProperty;
        else
            const isAtProperty = fd.type.isTypeFunction().isproperty;

        if (isAtProperty
            || fd.storage_class & DMD.STC.property
            || fd.storage_class2 & DMD.STC.property)
            warning(fd.loc, "Avoid the usage of `@property` attribute");

        // traverse through the AST
        super.visit(fd);
    }
}
