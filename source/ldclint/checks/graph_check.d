module ldclint.checks.graph_check;

import ldclint.utils.querier : Querier;
import ldclint.utils.visitor : ExtendedVisitor;
import ldclint.utils.graph;

import DMD = ldclint.dmd;

import std.string : fromStringz;

/// Base meta-check: owns the recursive traversal and emits node/edge events.
class GraphCheck(alias meta, V = ExtendedVisitor)
    : imported!"ldclint.checks".GenericCheck!(meta, V)
{
    alias visit = imported!"ldclint.checks".GenericCheck!(meta, V).visit;

    // ---- config hooks (override per tool) --------------------------------
    protected bool wantNode(NodeKind) { return true; }
    protected bool wantSize()         { return false; }

    // ---- event hooks (default: accumulate) -------------------------------
    protected Graph graph;

    protected void onNode(in NodeEvent e)
    {
        auto id = cast(void*)e.id;
        graph.nodes[id] = Node(id, e.kind, e.name, e.line, e.selfSize);
        if (e.isModule)
        {
            ModuleMeta mm;
            mm.file = e.file;
            mm.isRoot = e.isRoot;
            graph.modules[id] = mm;
        }
        else if (e.file.length)
            graph.fileOverride[id] = e.file;
    }

    protected void onEdge(in EdgeEvent e)
    {
        Edge edge;
        edge.from = cast(void*)e.from;
        edge.to = cast(void*)e.to;
        edge.isImport = e.isImport;
        edge.isPublicImport = e.isPublicImport;
        edge.isStaticImport = e.isStaticImport;
        graph.edges ~= edge;
    }

    protected void onComplete() { /* default: nothing */ }

    /// Bump a collapsed counter on the nearest enclosing module.
    protected void onCollapsed(void* moduleId, NodeKind kind)
    {
        if (auto mm = moduleId in graph.modules)
            mm.counts[kind]++;
    }

    // ---- traversal state -------------------------------------------------
    private bool[void*] visitedNodes;
    private void* parentId;
    private void* currentModuleId;   // nearest enclosing module node id
    private bool  walkedAllModules;

    // ---- dedup for import edges (owned by the visitor, not the model) ----
    private static struct EdgeKey { void* from; void* to; }
    private bool[EdgeKey] edgeSeen;
    private bool edgeIsNew(void* from, void* to)
    {
        auto key = EdgeKey(from, to);
        if (key in edgeSeen) return false;
        edgeSeen[key] = true;
        return true;
    }

    // ---- module entry point ---------------------------------------------
    override void visit(Querier!(DMD.Module) m)
    {
        if (!m.isValid()) return;

        auto astNode = cast(void*)m.astNode;
        if (astNode in visitedNodes) return;
        visitedNodes[astNode] = true;

        auto importedFrom = m.astNode.importedFrom;
        bool isRoot = importedFrom is null || importedFrom is m.astNode;

        const(char)[] file;
        auto locFile = fromStringz(m.loc.filename);
        if (!locFile.length && m.astNode.srcfile)
            file = fromStringz(m.astNode.srcfile.toChars());
        else
            file = locFile;

        NodeEvent ev;
        ev.id = astNode;
        ev.parentId = null;
        ev.kind = NodeKind.module_;
        ev.rawKind = fromStringz(m.kind());
        ev.name = m.toString();
        ev.file = file;
        ev.line = m.loc.linnum;
        ev.selfSize = wantSize() ? m.instanceSize() : 0;
        ev.isModule = true;
        ev.isRoot = isRoot;

        if (wantNode(NodeKind.module_))
            onNode(ev);

        auto prevParent = parentId;
        auto prevModule = currentModuleId;
        parentId = astNode;
        currentModuleId = astNode;
        scope(exit) { parentId = prevParent; currentModuleId = prevModule; }

        super.visit(m);

        if (!walkedAllModules)
        {
            walkedAllModules = true;
            scope(exit) walkedAllModules = false;

            foreach (other; m.astNode.amodules)
            {
                if (other is null || other is m.astNode) continue;
                other.accept(dmdVisitorProxy);
            }

            onComplete();
        }
    }

    // ---- generic symbol handler -----------------------------------------
    private void handle(T)(T node)
    {
        if (!node.isValid()) return;

        auto id = cast(void*)node.astNode;
        if (id in visitedNodes) return;
        visitedNodes[id] = true;

        auto raw = fromStringz(node.kind());
        auto kind = classify(raw);

        const(char)[] file = fromStringz(node.loc.filename);
        if (file.length && currentModule !is null && currentModule.srcfile)
        {
            auto modFile = fromStringz(currentModule.srcfile.toChars());
            if (modFile == file) file = null;
        }

        auto prev = parentId;
        scope(exit) parentId = prev;

        if (wantNode(kind))
        {
            NodeEvent ev;
            ev.id = id;
            ev.parentId = parentId;
            ev.kind = kind;
            ev.rawKind = raw;
            ev.name = node.toString();
            ev.file = file;
            ev.line = node.loc.linnum;
            ev.selfSize = wantSize() ? node.instanceSize() : 0;
            ev.isModule = false;
            onNode(ev);

            EdgeEvent ee;
            ee.from = parentId;
            ee.to = id;
            ee.isImport = false;
            onEdge(ee);

            parentId = id;   // only descend the materialized parent
        }
        else
        {
            onCollapsed(currentModuleId, kind);
        }

        super.visit(node);
    }

    override void visit(Querier!(DMD.StructDeclaration) n)    { handle(n); }
    override void visit(Querier!(DMD.UnionDeclaration) n)     { handle(n); }
    override void visit(Querier!(DMD.ClassDeclaration) n)     { handle(n); }
    override void visit(Querier!(DMD.InterfaceDeclaration) n) { handle(n); }
    override void visit(Querier!(DMD.EnumDeclaration) n)      { handle(n); }
    override void visit(Querier!(DMD.EnumMember) n)           { handle(n); }
    override void visit(Querier!(DMD.FuncDeclaration) n)      { handle(n); }
    override void visit(Querier!(DMD.VarDeclaration) n)       { handle(n); }
    override void visit(Querier!(DMD.AliasDeclaration) n)     { handle(n); }
    override void visit(Querier!(DMD.TemplateDeclaration) n)  { handle(n); }
    override void visit(Querier!(DMD.TemplateInstance) n)     { handle(n); }
    override void visit(Querier!(DMD.TemplateMixin) n)        { handle(n); }
    override void visit(Querier!(DMD.Import) n)
    {
        handle(n);   // materialize import_ node + containment edge (unchanged)

        // Dependency edge: enclosing module -> imported module, with the
        // public/static facts read off this Import node. Skip the implicit
        // object import and the DMD self-import artifact.
        if (n.isValid() && n.mod !is null
            && n.id != DMD.Id.object
            && currentModuleId !is null
            && cast(void*)n.mod !is currentModuleId)
        {
            auto to = cast(void*)n.mod;
            if (edgeIsNew(currentModuleId, to))
            {
                EdgeEvent ee;
                ee.from = currentModuleId;
                ee.to = to;
                ee.isImport = true;
                ee.isPublicImport = n.visibility.kind == DMD.Visibility.Kind.public_;
                ee.isStaticImport = n.isstatic != 0;
                onEdge(ee);
            }
        }
    }
}
