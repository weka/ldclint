module ldclint.checks.stack;

import ldclint.utils.querier : Querier, querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons : No, Yes, Flag;

enum Metadata = imported!"ldclint.checks".Metadata(
    "stack",
    No.byDefault,
);

final class Check : imported!"ldclint.checks".GenericCheck!Metadata
{
    alias visit = imported!"ldclint.checks".GenericCheck!Metadata.visit;

    enum size_t maxVariableStackSize = 256;

    DMD.ScopeTracker scopeTracker;

    override void visit(Querier!(DMD.FuncDeclaration) fd)
    {
        // lets skip invalid functions
        if (!fd.isValid()) return;

        auto sc = scopeTracker.track(fd);
        scope(exit) scopeTracker.untrack(fd, sc);

        // traverse through the AST
        super.visit(fd);
    }

    override void visit(Querier!(DMD.VarDeclaration) vd)
    {
        // lets skip invalid variable declarations
        if (!vd.isValid()) return;

        scope(exit)
        {
            // traverse through the AST
            super.visit(vd);
        }

        // not inside functions
        if (scopeTracker.functionDepth <= 0) return;

        // lets skip global variables inside functions
        if (vd.storage_class & DMD.STC.gshared || vd.storage_class & DMD.STC.static_)
            return;

        // lets skip extern symbols
        if (vd.storage_class & DMD.STC.extern_) return;

        // lets skip fields inside structs/classes
        if (vd.storage_class & DMD.STC.field) return;

        // lets skip references
        if (vd.storage_class & DMD.STC.ref_) return;

        // lets skip template parameters
        if (vd.storage_class & DMD.STC.templateparameter) return;

        DMD.Type type = vd.astNode.type;
        if (type is null) type = vd.astNode.originalType;
        if (type is null) return;

        auto rsz = querier(type).size;
        // unresolved size
        if (!rsz.resolved) return;

        auto sz = rsz.get;

        if (sz != size_t.max && sz > maxVariableStackSize)
        {
            warning(vd.loc, "Stack variable `%s` is big (size: %lu, limit: %lu)", vd.toChars(), sz, maxVariableStackSize);
        }
    }

    // avoid all sorts of false positives without semantics
    override void visit(Querier!(DMD.TemplateDeclaration)) { /* skip */ }
}
