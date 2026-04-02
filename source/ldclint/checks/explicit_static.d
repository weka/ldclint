module ldclint.checks.explicit_static;

import ldclint.utils.querier : Querier, querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons : No, Yes, Flag;

enum Metadata = imported!"ldclint.checks".Metadata(
    "explicit",
    "static",
    No.byDefault,
);

final class Check : imported!"ldclint.checks".GenericCheck!Metadata
{
    mixin imported!"ldclint.checks".RegisterCheck!Metadata;

    alias visit = imported!"ldclint.checks".GenericCheck!Metadata.visit;

    override void visit(Querier!(DMD.StructDeclaration) sd)
    {
        if (!sd.isValid()) return;

        // Check structs defined inside a function that are not
        // explicitly marked `static` and don't actually use
        // the enclosing scope. These get a hidden context
        // pointer unnecessarily.
        auto parent = sd.toParent();
        if (parent !is null && parent.isFuncDeclaration())
        {
            if (!(sd.storage_class & DMD.STC.static_) && !usesEnclosingScope(sd))
            {
                warning(sd.loc,
                    "Struct `%s` may generate an hidden context pointer",
                    sd.toChars());
            }
        }

        super.visit(sd);
    }

    /// Check if any member function of the struct references variables
    /// from the enclosing function scope (via outerVars).
    private static bool usesEnclosingScope(DMD.StructDeclaration sd)
    {
        if (sd.members is null) return false;

        foreach (sym; *sd.members)
        {
            if (sym is null) continue;
            auto fd = sym.isFuncDeclaration();
            if (fd is null) continue;
            // If any member function references outer variables,
            // the struct genuinely needs the context pointer.
            if (fd.outerVars.length > 0)
                return true;
        }
        return false;
    }

    // avoid false positives inside uninstantiated templates
    override void visit(Querier!(DMD.TemplateDeclaration)) { /* skip */ }
}
