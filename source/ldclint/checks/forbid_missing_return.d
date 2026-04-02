module ldclint.checks.forbid_missing_return;

import ldclint.utils.querier : Querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons : No, Yes, Flag;

enum Metadata = imported!"ldclint.checks".Metadata(
    "forbid",
    "missing-return",
    No.byDefault,
);

/// Checks for auto functions that resolve to void (likely missing a return statement).
/// Ported from D-Scanner's auto_function check (457fab85a737, https://github.com/dlang-community/D-Scanner).
final class Check : imported!"ldclint.checks".GenericCheck!Metadata
{
    mixin imported!"ldclint.checks".RegisterCheck!Metadata;

    alias visit = imported!"ldclint.checks".GenericCheck!Metadata.visit;

    override void visit(Querier!(DMD.FuncDeclaration) fd)
    {
        if (!fd.isValid()) return;

        // Only check functions declared with `auto`
        if (!(fd.storage_class & DMD.STC.auto_)) { super.visit(fd); return; }

        // Skip disabled functions
        if (fd.storage_class & DMD.STC.disable) { super.visit(fd); return; }

        // Skip functions without a body
        if (fd.fbody is null) { super.visit(fd); return; }

        // Skip if the body is a single return statement
        if (fd.fbody.isReturnStatement()) { super.visit(fd); return; }

        // Check the resolved return type
        if (fd.type is null) { super.visit(fd); return; }
        auto tf = fd.type.isTypeFunction();
        if (tf is null) { super.visit(fd); return; }

        // If the resolved return type is void, the auto function has no return
        if (tf.next !is null && tf.next.ty == DMD.Tvoid)
            warning(fd.loc,
                "Function declared `auto` inferred as `void`; add an explicit `void` return type, or add the missing `return`.");

        super.visit(fd);
    }

    // avoid false positives inside uninstantiated templates
    override void visit(Querier!(DMD.TemplateDeclaration)) { /* skip */ }
}
