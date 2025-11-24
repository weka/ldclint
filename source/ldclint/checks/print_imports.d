module ldclint.checks.print_imports;

import ldclint.utils.querier : Querier, querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons : No, Yes, Flag;
import std.stdio;
import std.string;

enum Metadata = imported!"ldclint.checks".Metadata(
    "print-imports",
    No.byDefault,
    Yes.allModules,
    1 /* priority */,
);

final class Check : imported!"ldclint.checks".GenericCheck!Metadata
{
    alias visit = imported!"ldclint.checks".GenericCheck!Metadata.visit;

    override void visit(Querier!(DMD.Import) imp)
    {
        writefln("%s -> %s",
            fromStringz(currentModule.toChars()),
            fromStringz(imp.toChars()),
        );

        super.visit(imp);
    }
}
