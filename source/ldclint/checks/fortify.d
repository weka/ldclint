module ldclint.checks.fortify;

import ldclint.utils.querier : Querier, querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons : No, Yes, Flag;

enum Metadata = imported!"ldclint.checks".Metadata(
    "fortify",
    No.byDefault,
);

final class Check : imported!"ldclint.checks".GenericCheck!Metadata
{
    mixin imported!"ldclint.checks".RegisterCheck!Metadata;

    alias visit = imported!"ldclint.checks".GenericCheck!Metadata.visit;

    override void visit(Querier!(DMD.CallExp) call)
    {
        // lets skip invalid calls
        if (!call.isValid()) return;

        // traverse through the AST
        super.visit(call);

        // lets skip if no function declaration symbol
        if (call.f is null) return;

        // placeholder for future fortify checks on C functions
        // (memcpy, memset, memcmp, strcpy, strcmp)
    }
}
