module ldclint.checks.destroy_ptr;

import ldclint.utils.querier : Querier, querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons : No, Yes, Flag;

enum Metadata = imported!"ldclint.checks".Metadata(
    "destroy-ptr",
    No.byDefault,
);

final class Check : imported!"ldclint.checks".GenericCheck!Metadata
{
    alias visit = imported!"ldclint.checks".GenericCheck!Metadata.visit;

    override void visit(Querier!(DMD.CallExp) call)
    {
        if (!call.isValid()) return;

        super.visit(call);

        if (!isDestroyCall(call)) return;

        // check if the first argument is a pointer type
        if (call.arguments is null || (*call.arguments).length == 0) return;

        auto arg = (*call.arguments)[0];
        if (arg is null) return;

        auto t = arg.type;
        if (t is null) return;

        if (t.toBasetype().ty == DMD.Tpointer)
        {
            warning(call.loc, "Calling `destroy()` on a pointer destroys the pointer itself, not the pointee");
        }
    }

    private static bool isDestroyCall(Querier!(DMD.CallExp) call)
    {
        // resolved case: check the function declaration
        if (call.f)
        {
            auto ident = call.f.ident;
            if (ident !is null && ident.toString() == "destroy")
                return true;
        }

        // unresolved case: check identifiers directly
        if (auto ide = call.e1.isIdentifierExp())
        {
            if (ide.ident !is null && ide.ident.toString() == "destroy")
                return true;
        }

        return false;
    }

    // avoid false positives inside uninstantiated templates
    override void visit(Querier!(DMD.TemplateDeclaration)) { /* skip */ }
}
