module ldclint.checks.import_cycle;

import DMD = ldclint.dmd;
import ldclint.checks : Parameter;
import ldclint.checks.graph_check : GraphCheck;
import ldclint.utils.graph;
import ldclint.utils.report;
import dmd.common.outbuffer : OutBuffer;
import std.typecons : Yes;
import std.algorithm : sort;

enum Metadata = imported!"ldclint.checks".Metadata(
    "import",
    "cycle",
    Yes.byDefault,
    [ Parameter("dot-file", Parameter.Type.string, "") ],
);

final class Check : GraphCheck!Metadata
{
    mixin imported!"ldclint.checks".RegisterCheck!Metadata;
    alias visit = GraphCheck!Metadata.visit;

    // Cycle detection only needs the module-level import graph; symbol nodes
    // are irrelevant, so collapse everything but modules.
    protected override bool wantNode(NodeKind k) { return k == NodeKind.module_; }
    protected override bool wantSize() { return false; }

    // Modules already included in a reported cycle — avoids duplicate reports
    // when several modules of one cycle are compiled together, and across
    // repeated onComplete drains over the growing graph.
    private bool[void*] reported;

    // Accumulated DOT edges across all reported cycles.
    private string[] dotEdges;
    private bool[string] edgeSeen;

    protected override void onComplete()
    {
        // Genuine cycles are strongly-connected components of size > 1 over
        // the import edges. Self-import artifacts were dropped at build time,
        // so a component is cyclic iff it has at least two modules.
        auto comp = stronglyConnected(graph);

        void*[][size_t] members;
        // AA-key iteration yields a const key even over a mutable AA.
        foreach (id, c; comp)
            members[c] ~= cast(void*)id;

        // One deterministic seed per cyclic component: the lexicographically
        // smallest module name AMONG THE ROOT MODULES in the component. We only
        // report cycles that involve a compiled root — transitively-imported
        // library cycles (e.g. within druntime) are not the user's concern and
        // would otherwise be false positives now that we walk amodules.
        DMD.Module[] seeds;
        foreach (c, group; members)
        {
            if (group.length < 2) continue;

            DMD.Module seed = null;
            foreach (id; group)
            {
                auto mm = id in graph.modules;
                if (mm is null || !mm.isRoot) continue;
                auto m = cast(DMD.Module)id;
                if (seed is null || modName(m) < modName(seed)) seed = m;
            }
            if (seed !is null) seeds ~= seed;
        }
        seeds.sort!((a, b) => modName(a) < modName(b));

        foreach (seed; seeds)
        {
            if (cast(void*)seed in reported) continue;
            DMD.Module[] path;
            bool[void*] visited;
            visited[cast(void*)seed] = true;
            findAndReport(seed, seed, path, visited);
        }

        if (dot_file.length)
            writeDotFile(dot_file);
    }

    private bool findAndReport(
        DMD.Module root, DMD.Module current,
        ref DMD.Module[] path, ref bool[void*] visited)
    {
        path ~= current;
        foreach (imp; current.aimports)
        {
            if (imp is null) continue;
            if (imp is root)
            {
                foreach (mod; path)
                    reported[cast(void*)mod] = true;
                // A module appearing in its own aimports is a DMD artefact,
                // not a real cycle between distinct modules — skip it.
                if (path.length > 1)
                    reportCycle(root, path);
                return true;
            }
            auto k = cast(void*)imp;
            if (k in visited) continue;
            visited[k] = true;
            if (findAndReport(root, imp, path, visited)) return true;
        }
        path = path[0 .. $ - 1];
        return false;
    }

    private void reportCycle(DMD.Module root, DMD.Module[] path)
    {
        // Module.loc is Loc.initial — use the first outgoing import statement
        // in the root module as the primary warning location.
        auto firstEdgeLoc = path.length > 1
            ? importLoc(root, path[1])
            : root.loc;
        warning(firstEdgeLoc, "module `%s` imports itself", modName(root).ptr);
        foreach (i, mod; path)
        {
            auto next = (i + 1 < path.length) ? path[i + 1] : root;
            auto loc = importLoc(mod, next);
            DMD.warningSupplemental(loc,
                "`%s` imports `%s`", modName(mod).ptr, modName(next).ptr);
        }

        if (dot_file.length == 0) return;

        foreach (i, mod; path)
        {
            auto next = (i + 1 < path.length) ? path[i + 1] : root;
            auto edge = "    \""
                ~ modName(mod).idup ~ "\" -> \""
                ~ modName(next).idup ~ "\";";
            if (edge !in edgeSeen)
            {
                edgeSeen[edge] = true;
                dotEdges ~= edge;
            }
        }
    }

    private void writeDotFile(string path)
    {
        import std.stdio : File;
        auto f = File(path, "w");
        f.writeln("digraph {");
        foreach (edge; dotEdges)
            f.writeln(edge);
        f.writeln("}");
    }

    // Returns the location of the `import target;` statement inside `from`.
    // Falls back to from.loc (module declaration) if the import isn't found
    // at the top level (e.g., it lives inside a version block).
    private static DMD.Loc importLoc(DMD.Module from, DMD.Module to)
    {
        if (from.members is null) return from.loc;
        foreach (sym; *from.members)
        {
            if (sym is null) continue;
            auto imp = sym.isImport();
            if (imp !is null && imp.mod is to) return imp.loc;
        }
        return from.loc;
    }

    private static const(char)[] modName(DMD.Module mod)
    {
        OutBuffer buf;
        mod.fullyQualifiedName(buf);
        return buf.extractSlice(true);
    }
}
