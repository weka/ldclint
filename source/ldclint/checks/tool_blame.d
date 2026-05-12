module ldclint.checks.tool_blame;

import ldclint.utils.querier : Querier, querier;
import ldclint.utils.visitor : ExtendedVisitor;
import ldclint.checks : Parameter;

import DMD = ldclint.dmd;

import std.typecons;
import std.stdio : File;
import std.string : fromStringz;
import std.array : Appender, appender;
import std.format : formattedWrite;
import core.atomic : cas;

enum Metadata = imported!"ldclint.checks".Metadata(
    "tool",
    "blame",
    No.byDefault,
    [ Parameter("path", Parameter.Type.string, "./blame.log") ],
    Yes.allModules,
);

/// Emits one CSV row per visited symbol with the AST node's *compiler*
/// memory footprint — the size of the dynamic class instance the frontend
/// allocates, not the runtime memory the declaration would consume.
///
/// The intent is to attribute compiler memory (and symbol counts) to
/// source-level scopes so downstream tooling can `SUM(bytes) GROUP BY
/// scope` to find the hot spots.
///
/// Rows are flushed as each symbol is visited (no in-memory batching) — a
/// crash mid-traversal still leaves a partial-but-valid file. Output path
/// is configurable via the `path` parameter (`-Wtool-blame=path=foo.log`).
///
/// Columns:
///
///   node   — opaque pointer (hex) identifying the AST node — stable for
///            the duration of the compile. Lets downstream tools join
///            children to parents.
///   parent — `node` value of the enclosing AST symbol, or empty for the
///            module row (root). Read straight from `Dsymbol.parent`.
///   module — fully qualified module name.
///   scope  — `.`-joined containing scope (e.g. `Outer.Inner`); empty at
///            module scope. Stack frames a flamegraph tool can fold on.
///   name   — symbol name; empty for unnamed aggregates.
///   kind   — module, struct, class, interface, union, enum, enum-member,
///            field, variable, function, alias, template, template-inst,
///            mixin-template, import.
///   bytes  — `__traits(classInstanceSize, ...)` of the AST class the
///            frontend allocated for this symbol — its compiler-memory
///            footprint, not the runtime type size.
///   file   — source path.
///   line   — line number.
final class Check : imported!"ldclint.checks".GenericCheck!(Metadata, ExtendedVisitor)
{
    mixin imported!"ldclint.checks".RegisterCheck!Metadata;

    alias visit = imported!"ldclint.checks".GenericCheck!(Metadata, ExtendedVisitor).visit;

    /// Lazily-opened output file, append-mode so multi-module compiles
    /// share a single CSV.
    private File _output;
    private ref File output()
    {
        if (!_output.isOpen)
        {
            _output = File(this.path, "a");
            _output.lock();
            scope(exit) _output.unlock();

            if (_output.size == 0)
            {
                static immutable header =
                    "kind,hash,addr,phash,paddr,file,line,name,size\n";
                _output.rawWrite(header);
                _output.flush();
            }
        }
        return _output;
    }

    // ─── module (entry point) ──────────────────────────────────

    /// Re-entrancy flag: only the *outermost* `visit(Module)` call
    /// chases `Module.amodules`.
    private bool walkedAllModules;

    override void visit(Querier!(DMD.Module) m)
    {
        if (!m.isValid()) return;

        bool alreadyVisited;
        auto ns = pushNode(m, alreadyVisited);
        scope(exit) popNode(ns);
        if (alreadyVisited) return;

        super.visit(m);

        // Only the outermost module visit chases the global flat list
        // of every loaded module. The visited-set keeps each module to
        // exactly one row even when reached through multiple roots.
        if (!walkedAllModules)
        {
            walkedAllModules = true;
            scope(exit) walkedAllModules = false;

            foreach (other; m.amodules)
            {
                if (other is null || other is m.astNode) continue;
                other.accept(dmdVisitorProxy);
            }
        }
    }

    // ─── aggregates ────────────────────────────────────────────

    override void visit(Querier!(DMD.StructDeclaration) sd)
    {
        if (!sd.isValid()) return;

        bool alreadyVisited;
        auto ns = pushNode(sd, alreadyVisited);
        scope(exit) popNode(ns);
        if (alreadyVisited) return;

        super.visit(sd);
    }

    override void visit(Querier!(DMD.UnionDeclaration) ud)
    {
        if (!ud.isValid()) return;

        bool alreadyVisited;
        auto ns = pushNode(ud, alreadyVisited);
        scope(exit) popNode(ns);
        if (alreadyVisited) return;

        super.visit(ud);
    }

    override void visit(Querier!(DMD.ClassDeclaration) cd)
    {
        if (!cd.isValid()) return;

        bool alreadyVisited;
        auto ns = pushNode(cd, alreadyVisited);
        scope(exit) popNode(ns);
        if (alreadyVisited) return;

        super.visit(cd);
    }

    override void visit(Querier!(DMD.InterfaceDeclaration) id)
    {
        if (!id.isValid()) return;

        bool alreadyVisited;
        auto ns = pushNode(id, alreadyVisited);
        scope(exit) popNode(ns);
        if (alreadyVisited) return;

        super.visit(id);
    }

    override void visit(Querier!(DMD.EnumDeclaration) ed)
    {
        if (!ed.isValid()) return;

        bool alreadyVisited;
        auto ns = pushNode(ed, alreadyVisited);
        scope(exit) popNode(ns);
        if (alreadyVisited) return;

        super.visit(ed);
    }

    override void visit(Querier!(DMD.EnumMember) em)
    {
        if (!em.isValid()) return;
        
        bool alreadyVisited;
        auto ns = pushNode(em, alreadyVisited);
        scope(exit) popNode(ns);
        if (alreadyVisited) return;

        super.visit(em);
    }

    // ─── functions / variables ────────────────────────────────

    override void visit(Querier!(DMD.FuncDeclaration) fd)
    {
        if (!fd.isValid()) return;

        bool alreadyVisited;
        auto ns = pushNode(fd, alreadyVisited);
        scope(exit) popNode(ns);
        if (alreadyVisited) return;

        super.visit(fd);
    }

    override void visit(Querier!(DMD.VarDeclaration) vd)
    {
        if (!vd.isValid()) return;

        bool alreadyVisited;
        auto ns = pushNode(vd, alreadyVisited);
        scope(exit) popNode(ns);
        if (alreadyVisited) return;

        super.visit(vd);
    }

    // ─── aliases / templates / imports ────────────────────────

    override void visit(Querier!(DMD.AliasDeclaration) ad)
    {
        if (!ad.isValid()) return;

        bool alreadyVisited;
        auto ns = pushNode(ad, alreadyVisited);
        scope(exit) popNode(ns);
        if (alreadyVisited) return;

        super.visit(ad);
    }

    override void visit(Querier!(DMD.TemplateDeclaration) td)
    {
        if (!td.isValid()) return;

        bool alreadyVisited;
        auto ns = pushNode(td, alreadyVisited);
        scope(exit) popNode(ns);
        if (alreadyVisited) return;

        super.visit(td);
    }

    override void visit(Querier!(DMD.TemplateInstance) ti)
    {
        if (!ti.isValid()) return;
        
        bool alreadyVisited;
        auto ns = pushNode(ti, alreadyVisited);
        scope(exit) popNode(ns);
        if (alreadyVisited) return;

        super.visit(ti);
    }

    override void visit(Querier!(DMD.TemplateMixin) tm)
    {
        if (!tm.isValid()) return;

        bool alreadyVisited;
        auto ns = pushNode(tm, alreadyVisited);
        scope(exit) popNode(ns);
        if (alreadyVisited) return;

        super.visit(tm);
    }

    override void visit(Querier!(DMD.Import) imp)
    {
        if (!imp.isValid()) return;

        bool alreadyVisited;
        auto ns = pushNode(imp, alreadyVisited);
        scope(exit) popNode(ns);
        if (alreadyVisited) return;

        super.visit(imp);
    }

    // ─── helpers ───────────────────────────────────────────────

    /// temporary append buffer to write blame row
    private Appender!(char[]) tempBuffer;

    import std.typecons : Tuple, tuple;
    /// parent (in terms of dependency) or previously visited AST node pointer
    private Tuple!(void*, "ptr", size_t, "hash") parentNode = tuple(null, 0);

    /// parent module location (in terms of dependency) or previously visited non-module node location
    private char[] parentModuleFile = null;

    /// AST nodes we've already emitted a row for. With the plugin
    /// reusing a single Check instance across every
    /// `runSemanticAnalysis` call, this set lives for the whole
    /// compile, so transitively-imported modules reached via
    /// `Module.amodules` are mapped exactly once regardless of how
    /// many roots discover them.
    private bool[void*] visitedNodes;

    private auto pushNode(T)(T node, out bool alreadyVisited)
    {
        if (!node.isValid()) return parentNode;

        auto prev = parentNode;
        auto astNode = node.astNode;
        auto ptr = (cast(void*)astNode);

        if (ptr in visitedNodes)
        {
            alreadyVisited = true;
            return prev;
        }
        visitedNodes[ptr] = true;

        const(char)[] name;

        static if (is(typeof(astNode) : DMD.Module))
        {
            auto importedFrom = astNode.importedFrom;
            if (importedFrom is null || importedFrom is astNode)
                parentNode = tuple(null, 0);
            else
                parentNode.ptr = cast(void*)importedFrom;
                name = querier(importedFrom).toString();
                parentNode.hash = hashOf(name, 0);
        }

        name = node.toString();
        auto sz = node.instanceSize();
        auto kind = fromStringz(node.kind());
        auto hash = hashOf(name, hashOf(":",
                                 hashOf(kind,
                                 hashOf(sz,
                                 hashOf("::", parentNode.hash)))));
        registerRow(node, kind, name, hash, sz);

        parentNode.ptr = cast(void*)astNode;
        parentNode.hash = hash;

        return prev;
    }

    private void popNode(typeof(parentNode) prev)
    {
        parentNode = prev;
    }

    private void registerRow(T)(T node, const(char)[] kind, const(char)[] name, size_t hash, size_t sz)
    {
        // Modules carry their path in `srcfile`, not `loc.filename` (which
        // is the synthetic module-decl location). Fall back accordingly.
        auto file = fromStringz(node.loc.filename);
        static if (is(typeof(node.astNode) : DMD.Module))
        {
            if (!file.length && node.astNode.srcfile)
                file = fromStringz(node.astNode.srcfile.toChars());
        }
        else
        {
            if (file.length && currentModule !is null && currentModule.srcfile)
            {
                auto modFile = fromStringz(currentModule.srcfile.toChars());
                if (modFile == file)
                    file = null;
            }
        }

        tempBuffer.clear();

        tempBuffer.formattedWrite!"%s,0x%X,0x%X,0x%X,0x%X,%s,%d,%s,%d\n"(
            kind,
            hash,
            cast(size_t)cast(void*)node.astNode,
            parentNode.hash,
            parentNode.ptr,
            csvField(file),
            node.loc.linnum,
            csvField(name),
            sz
        );

        auto f = output();
        f.lock();
        scope(exit) f.unlock();
        
        f.rawWrite(tempBuffer[]);
        f.flush();
    }

    /// Minimal RFC-4180-ish escaping: wrap in quotes and double existing
    /// quotes if the field contains a comma, quote, newline, or CR.
    private static const(char)[] csvField(const(char)[] s)
    {
        bool needsQuoting = false;
        foreach (c; s)
            if (c == ',' || c == '"' || c == '\n' || c == '\r')
                { needsQuoting = true; break; }
        if (!needsQuoting) return s;

        import std.array : appender;
        auto app = appender!(char[]);
        app ~= '"';
        foreach (c; s)
        {
            if (c == '"') app ~= '"';
            if (c == '\n' || c == '\r') app ~= ' ';
            else app ~= c;
        }
        app ~= '"';
        return app[];
    }
}
