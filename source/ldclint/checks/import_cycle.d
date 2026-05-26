module ldclint.checks.import_cycle;

import DMD = ldclint.dmd;
import ldclint.checks : Parameter;
import ldclint.utils.querier : Querier;
import ldclint.utils.report;
import dmd.common.outbuffer : OutBuffer;
import std.typecons : No, Yes;

enum Metadata = imported!"ldclint.checks".Metadata(
    "import",
    "cycle",
    Yes.byDefault,
    [ Parameter("dot-file", Parameter.Type.string, "") ],
);

final class Check : imported!"ldclint.checks".GenericCheck!Metadata
{
    mixin imported!"ldclint.checks".RegisterCheck!Metadata;
    alias visit = imported!"ldclint.checks".GenericCheck!Metadata.visit;

    // Modules already included in a reported cycle — avoids duplicate reports
    // when multiple root modules in the same cycle are compiled together.
    static __gshared bool[void*] reported;

    // Accumulated DOT edges across all visit(Module) calls.
    static __gshared string[] dotEdges;
    static __gshared bool[string] edgeSeen;

    override void visit(Querier!(DMD.Module) m)
    {
        if (!m.isValid()) return;

        auto key = cast(void*)m.astNode;
        if (key !in reported && m.selfImports())
        {
            DMD.Module[] path;
            bool[void*] visited;
            visited[key] = true;
            findAndReport(m.astNode, m.astNode, path, visited);
        }

        super.visit(m);
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

        auto filePath = dot_file;
        if (filePath.length == 0) return;

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
        writeDotFile(filePath);
    }

    private static void writeDotFile(string path)
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
