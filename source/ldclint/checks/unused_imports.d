module ldclint.checks.unused_imports;

import ldclint.utils.querier : Querier, querier;
import ldclint.utils.visitor : ExtendedVisitor;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import dmd.common.outbuffer : OutBuffer;

import std.typecons : No, Yes, Flag;

enum Metadata = imported!"ldclint.checks".Metadata(
    "unused",
    "imports",
    No.byDefault,
);

final class Check : imported!"ldclint.checks".GenericCheck!(Metadata, ExtendedVisitor)
{
    mixin imported!"ldclint.checks".RegisterCheck!Metadata;

    alias visit = imported!"ldclint.checks".GenericCheck!(Metadata, ExtendedVisitor).visit;

    static struct Context
    {
        /// number of references for an imported module
        size_t[void*] refs;

        /// first private import per imported module — used as the warning location
        DMD.Import[void*] firstImport;

        /// unresolved identifiers seen in expressions/dot-access (e.g. inside
        /// uninstantiated templates) — checked at reporting time so that an
        /// import is not flagged when its module exports a matching symbol.
        void[0][const(char)[]] unresolvedIdents;

        void track(DMD.Import imp)
        {
            if (imp is null || imp.mod is null) return;

            auto key = cast(void*)imp.mod;
            this.refs.require(key, 0);
            this.firstImport.require(key, imp);
        }

        void incrementRef(T)(T s)
            if (is(T : DMD.Dsymbol))
        {
            if (s is null) return;
            auto m = s.getModule();
            if (m is null) return;
            ++this.refs.require(cast(void*)m, 0);
        }

        void collectIdent(DMD.Identifier ident)
        {
            if (ident is null || ident.isAnonymous()) return;
            auto str = ident.toString();
            if (str.length)
                unresolvedIdents[str] = (void[0]).init;
        }
    }

    /// per-module tracking state
    Context context;

    override void visit(Querier!(DMD.Module) m)
    {
        if (!m.isValid()) return;

        super.visit(m);

        foreach (omod, num; context.refs)
        {
            if (omod is null) continue;
            if (num > 0) continue;

            auto mod = cast(DMD.Module)omod;
            assert(mod, "must be a Module");

            // an unresolved identifier in this module may come from `mod` —
            // avoid false positives for imports used only inside
            // uninstantiated templates / mixin bodies.
            if (referencedByUnresolvedIdent(mod)) continue;

            auto imp = context.firstImport.get(omod, null);
            if (imp is null) continue;

            warning(imp.loc,
                "Imported module `%s` appears to be unused",
                fullyQualifiedName(mod).ptr);
        }
    }

    private bool referencedByUnresolvedIdent(DMD.Module mod)
    {
        if (context.unresolvedIdents.length == 0) return false;

        auto modSym = cast(DMD.Dsymbol)mod;
        if (modSym is null) return false;

        foreach (ident, _; context.unresolvedIdents)
        {
            auto sym = querier(modSym).hasSymbol(DMD.Identifier.idPool(ident));
            if (sym.astNode !is null) return true;
        }
        return false;
    }

    private static const(char)[] fullyQualifiedName(DMD.Module mod)
    {
        OutBuffer buf;
        mod.fullyQualifiedName(buf);
        return buf.extractSlice(true);
    }

    override void visit(Querier!(DMD.Import) imp)
    {
        if (imp.astNode is null) return;
        // skip the implicit object module import
        if (imp.id == DMD.Id.object) return;
        // skip publicly-exposed imports (public/package/protected/export);
        // they are intentional re-exports, not candidates for unused checks.
        if (imp.visibility > DMD.Visibility(DMD.Visibility.Kind.private_))
            return;

        context.track(imp);
    }

    override void visit(Querier!(DMD.CallExp) e)
    {
        if (!e.isValid()) return;
        super.visit(e);

        if (e.f) context.incrementRef(e.f);
    }

    override void visit(Querier!(DMD.NewExp) e)
    {
        if (!e.isValid()) return;
        super.visit(e);

        if (e.member) context.incrementRef(e.member);
    }

    /// `@StructType(args)` UDAs and value-construction patterns lower to a
    /// `StructLiteralExp` whose `sd` field is the only direct link to the
    /// declaring module — the default visit only walks the elements.
    override void visit(Querier!(DMD.StructLiteralExp) e)
    {
        if (!e.isValid()) return;
        super.visit(e);

        context.incrementRef(e.sd);
    }

    override void visit(Querier!(DMD.VarExp) e)
    {
        if (!e.isValid()) return;
        super.visit(e);
        context.incrementRef(e.var);
    }

    override void visit(Querier!(DMD.ThisExp) e)
    {
        if (!e.isValid()) return;
        super.visit(e);
        context.incrementRef(e.var);
    }

    override void visit(Querier!(DMD.DotVarExp) e)
    {
        if (!e.isValid()) return;
        super.visit(e);
        context.incrementRef(e.var);
    }

    override void visit(Querier!(DMD.SymOffExp) e)
    {
        if (!e.isValid()) return;
        super.visit(e);
        context.incrementRef(e.var);
    }

    override void visit(Querier!(DMD.SymbolExp) e)
    {
        if (!e.isValid()) return;
        super.visit(e);
        context.incrementRef(e.var);
    }

    override void visit(Querier!(DMD.DelegateExp) e)
    {
        if (!e.isValid()) return;
        super.visit(e);
        context.incrementRef(e.func);
    }

    override void visit(Querier!(DMD.ScopeExp) e)
    {
        if (!e.isValid()) return;
        super.visit(e);
        context.incrementRef(e.sds);
    }

    override void visit(Querier!(DMD.TemplateInstance) ti)
    {
        if (!ti.isValid()) return;
        super.visit(ti);
        context.incrementRef(ti.tempdecl);
    }

    override void visit(Querier!(DMD.TemplateMixin) tm)
    {
        if (!tm.isValid()) return;
        super.visit(tm);
        context.incrementRef(tm.tempdecl);
    }

    override void visit(Querier!(DMD.TypeStruct) t)
    {
        if (!t.isValid()) return;
        super.visit(t);
        context.incrementRef(t.sym);
    }

    override void visit(Querier!(DMD.TypeClass) t)
    {
        if (!t.isValid()) return;
        super.visit(t);
        context.incrementRef(t.sym);
    }

    override void visit(Querier!(DMD.TypeEnum) t)
    {
        if (!t.isValid()) return;
        super.visit(t);
        context.incrementRef(t.sym);
    }

    /// Collect unresolved identifiers — referenced names whose owning symbol
    /// is not yet known (typical inside uninstantiated templates).
    override void visit(Querier!(DMD.IdentifierExp) e)
    {
        if (!e.isValid()) return;
        super.visit(e);
        context.collectIdent(e.ident);
    }

    /// Collect the right-hand identifier from dot expressions where the
    /// symbol couldn't be resolved (e.g. inside uninstantiated templates,
    /// where `m.foo` does not lower to `DotVarExp`).
    override void visit(Querier!(DMD.DotIdExp) e)
    {
        if (!e.isValid()) return;
        super.visit(e);
        context.collectIdent(e.ident);
    }
}
