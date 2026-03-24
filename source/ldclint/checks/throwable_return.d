module ldclint.checks.throwable_return;

import ldclint.utils.querier : Querier, querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons : No, Yes, Flag;

enum Metadata = imported!"ldclint.checks".Metadata(
    "throwable-return",
    No.byDefault,
);

final class Check : imported!"ldclint.checks".GenericCheck!Metadata
{
    alias visit = imported!"ldclint.checks".GenericCheck!Metadata.visit;

    override void visit(Querier!(DMD.ExpStatement) s)
    {
        if (!s.isValid()) return;

        // check if the statement's expression is a discarded call
        if (s.exp !is null)
        {
            // the expression might be wrapped in a CastExp(void) by DMD
            DMD.Expression e = s.exp;
            if (auto ce = e.isCastExp())
            {
                if (ce.type && ce.type.toBasetype().ty == DMD.Tvoid)
                    e = ce.e1;
            }

            if (auto call = e.isCallExp())
                checkThrowableReturn(call);
        }

        super.visit(s);
    }

    private void checkThrowableReturn(DMD.CallExp call)
    {
        if (call.type is null) return;

        // skip constructor calls (super(), this())
        if (call.f)
        {
            if (call.f.isCtorDeclaration())
                return;
        }

        auto retType = call.type.toBasetype();
        if (retType is null) return;

        // check if return type is a class that derives from Throwable
        auto cd = retType.isClassHandle();
        if (cd is null) return;

        if (isThrowable(cd))
        {
            warning(call.loc,
                "Return value of type `%s` (derives from Throwable) is discarded",
                retType.toChars());
        }
    }

    private static bool isThrowable(DMD.ClassDeclaration cd)
    {
        // walk the class hierarchy
        while (cd !is null)
        {
            if (cd.ident == DMD.Id.Throwable)
                return true;
            if (cd.ident == DMD.Id.Exception)
                return true;
            if (cd.ident == DMD.Id.Error)
                return true;
            cd = cd.baseClass;
        }
        return false;
    }

    // avoid false positives inside uninstantiated templates
    override void visit(Querier!(DMD.TemplateDeclaration)) { /* skip */ }
}
