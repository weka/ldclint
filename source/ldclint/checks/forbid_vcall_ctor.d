module ldclint.checks.forbid_vcall_ctor;

import ldclint.utils.querier : Querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons : No, Yes, Flag;

enum Metadata = imported!"ldclint.checks".Metadata(
    "forbid",
    "vcall-ctor",
    No.byDefault,
);

/// Checks for virtual function calls inside constructors, which may lead to
/// unexpected results in derived classes.
/// Ported from D-Scanner's vcall_in_ctor check (457fab85a737, https://github.com/dlang-community/D-Scanner).
final class Check : imported!"ldclint.checks".GenericCheck!Metadata
{
    mixin imported!"ldclint.checks".RegisterCheck!Metadata;

    alias visit = imported!"ldclint.checks".GenericCheck!Metadata.visit;

    private static struct ClassContext
    {
        bool canBeVirtual;
        bool hasNonVirtualVis;
        bool hasNonVirtualStg;
        bool inCtor;
    }

    private static struct CallInfo
    {
        string funcName;
        DMD.Loc loc;
    }

    private ClassContext[] contexts;
    private bool[string] virtualFuncs;
    private CallInfo[] ctorCalls;
    private bool isFinal;

    override void visit(Querier!(DMD.ClassDeclaration) d)
    {
        if (!d.isValid()) return;

        pushContext((d.storage_class & DMD.STC.final_) == 0 && !isFinal);

        // Manually iterate members to collect virtual funcs and ctor calls
        if (d.members)
            foreach (s; *d.members)
                s.accept(dmdVisitorProxy);

        checkForVirtualCalls();
        popContext();
    }

    override void visit(Querier!(DMD.StructDeclaration) d)
    {
        if (!d.isValid()) return;

        // Structs don't have virtual dispatch
        pushContext(false);
        super.visit(d);
        checkForVirtualCalls();
        popContext();
    }

    override void visit(Querier!(DMD.VisibilityDeclaration) vd)
    {
        if (!vd.isValid()) return;

        if (contexts.length == 0)
        {
            super.visit(vd);
            return;
        }

        bool oldVis = currentContext.hasNonVirtualVis;
        currentContext.hasNonVirtualVis =
            vd.visibility.kind == DMD.Visibility.Kind.private_
            || vd.visibility.kind == DMD.Visibility.Kind.package_;
        super.visit(vd);
        currentContext.hasNonVirtualVis = oldVis;
    }

    override void visit(Querier!(DMD.StorageClassDeclaration) stgDecl)
    {
        if (!stgDecl.isValid()) return;

        bool oldFinal = isFinal;
        isFinal = (stgDecl.stc & DMD.STC.final_) != 0;

        bool oldStg;
        if (contexts.length > 0)
        {
            oldStg = currentContext.hasNonVirtualStg;
            currentContext.hasNonVirtualStg =
                cast(bool)(stgDecl.stc & DMD.STC.static_)
                || cast(bool)(stgDecl.stc & DMD.STC.final_);
        }

        super.visit(stgDecl);

        isFinal = oldFinal;
        if (contexts.length > 0)
            currentContext.hasNonVirtualStg = oldStg;
    }

    override void visit(Querier!(DMD.FuncDeclaration) fd)
    {
        if (!fd.isValid()) return;

        if (contexts.length == 0)
        {
            super.visit(fd);
            return;
        }

        bool hasNonVirtualStg = currentContext.hasNonVirtualStg
            || cast(bool)(fd.storage_class & DMD.STC.static_)
            || cast(bool)(fd.storage_class & DMD.STC.final_);

        // After semantic analysis, any non-private/non-final/non-static method
        // in a non-final class is virtual. No need for empty-body heuristic.
        if (currentContext.canBeVirtual && !currentContext.hasNonVirtualVis
            && !hasNonVirtualStg && fd.ident !is null)
        {
            string funcName = cast(string) fd.ident.toString();
            virtualFuncs[funcName] = true;
        }

        super.visit(fd);
    }

    override void visit(Querier!(DMD.CtorDeclaration) d)
    {
        if (!d.isValid()) return;

        if (contexts.length == 0)
        {
            super.visit(d);
            return;
        }

        currentContext.inCtor = true;
        super.visit(d);
        currentContext.inCtor = false;
    }

    override void visit(Querier!(DMD.CallExp) e)
    {
        if (!e.isValid()) return;

        super.visit(e);

        if (contexts.length == 0) return;

        if (!currentContext.inCtor) return;

        if (e.e1 is null) return;

        string funcCall;

        // Pre-semantic: IdentifierExp (unresolved foo())
        if (auto identExp = e.e1.isIdentifierExp())
            funcCall = cast(string) identExp.ident.toString();
        // Post-semantic: DotVarExp (resolved this.foo())
        else if (auto dotVar = e.e1.isDotVarExp())
        {
            if (dotVar.var !is null && dotVar.var.ident !is null)
                funcCall = cast(string) dotVar.var.ident.toString();
        }

        // Fallback: use the resolved function directly
        if (funcCall is null && e.f !is null && e.f.ident !is null)
            funcCall = cast(string) e.f.ident.toString();

        if (funcCall is null) return;
        ctorCalls ~= CallInfo(funcCall, e.loc);
    }

    private void checkForVirtualCalls()
    {
        foreach (ref call; ctorCalls)
        {
            if (call.funcName in virtualFuncs)
                warning(call.loc,
                    "Calling virtual method `%s` in a constructor dispatches to "
                    ~ "this class, not to any derived class override.", call.funcName.ptr);
        }

        ctorCalls.length = 0;
        virtualFuncs.clear();
    }

    private ref ClassContext currentContext() @property
    {
        return contexts[$ - 1];
    }

    private void pushContext(bool canBeVirtual)
    {
        contexts ~= ClassContext(canBeVirtual);
    }

    private void popContext()
    {
        contexts.length--;
    }

    // avoid false positives inside uninstantiated templates
    override void visit(Querier!(DMD.TemplateDeclaration)) { /* skip */ }
}
