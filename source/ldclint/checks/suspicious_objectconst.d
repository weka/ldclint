module ldclint.checks.suspicious_objectconst;

import ldclint.utils.querier : Querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons : No, Yes, Flag;

enum Metadata = imported!"ldclint.checks".Metadata(
    "suspicious",
    "objectconst",
    No.byDefault,
);

/// Checks that opEquals, opCmp, toHash, and toString are const.
/// Ported from D-Scanner's objectconst check (457fab85a737, https://github.com/dlang-community/D-Scanner).
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

    override void visit(Querier!(DMD.InterfaceDeclaration) d)
    {
        if (!d.isValid()) return;

        checkAggregate(d);
        super.visit(d);
    }

    override void visit(Querier!(DMD.UnionDeclaration) d)
    {
        if (!d.isValid()) return;

        checkAggregate(d);
        super.visit(d);
    }

    private void checkAggregate(T)(T ad)
    {
        if (ad.members is null) return;

        foreach (member; *ad.members)
        {
            if (auto fd = member.isFuncDeclaration())
                checkMethod(fd);
            else if (auto scd = member.isStorageClassDeclaration())
            {
                if (scd.decl)
                    foreach (smember; *scd.decl)
                        if (auto fd = smember.isFuncDeclaration())
                            checkMethodWithStc(fd, scd.stc);
            }
        }
    }

    private void checkMethod(DMD.FuncDeclaration fd)
    {
        checkMethodWithStc(fd, 0);
    }

    private void checkMethodWithStc(DMD.FuncDeclaration fd, ulong parentStc)
    {
        if (fd.storage_class & DMD.STC.disable) return;

        auto name = fd.ident.toString();
        if (name != "opEquals" && name != "opCmp" && name != "toHash" && name != "toString")
            return;

        if (isConstFunc(fd, parentStc)) return;

        warning(fd.loc, "`%s` should be marked `const` to work with `const` and `immutable` receivers.", name.ptr);
    }

    private static bool isConstFunc(DMD.FuncDeclaration fd, ulong parentStc)
    {
        // Check storage class on function or parent
        auto stc = fd.storage_class | parentStc;
        if (stc & DMD.STC.const_ || stc & DMD.STC.immutable_ || stc & DMD.STC.wild)
            return true;

        // Check type modifiers
        if (fd.type !is null)
        {
            auto mod = fd.type.mod;
            if (mod & DMD.MODFlags.const_ || mod & DMD.MODFlags.immutable_ || mod & DMD.MODFlags.wild)
                return true;
        }

        return false;
    }

    // avoid false positives inside uninstantiated templates
    override void visit(Querier!(DMD.TemplateDeclaration)) { /* skip */ }
}
