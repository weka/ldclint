module ldclint.checks.tool_graph;

import ldclint.checks : Parameter;
import ldclint.checks.graph_check : GraphCheck;
import ldclint.utils.graph;
import std.typecons : No, Yes;
import std.string : split;
import std.algorithm : canFind;
import std.stdio : File;

enum Metadata = imported!"ldclint.checks".Metadata(
    "tool",
    "graph",
    No.byDefault,
    [
        Parameter("nodes",   Parameter.Type.string, "module,import"),
        Parameter("metrics", Parameter.Type.string, ""),
        Parameter("path",    Parameter.Type.string, "./graph.dot"),
    ],
    Yes.allModules,
);

/// Emits a DOT module-dependency graph over the shared GraphCheck core.
/// Each module is a `subgraph cluster_*`; inter-module import edges connect
/// module anchor nodes with `compound`/`lhead`. Which symbol kinds are
/// materialized inside clusters is controlled by `nodes` (an include list);
/// kinds not listed are collapsed into per-module `n_<kind>` counters. The
/// `metrics=size` param attaches each node's compiler-memory `selfsize`.
///
/// NOTE: LDCLINT_FLAGS splits param values on commas, so a multi-kind `nodes`
/// list can only be supplied via the built-in default ("module,import");
/// passing `nodes=a,b` on the command line is not currently possible. Single
/// values (e.g. `nodes=module`) work.
final class Check : GraphCheck!Metadata
{
    mixin imported!"ldclint.checks".RegisterCheck!Metadata;
    alias visit = GraphCheck!Metadata.visit;

    private bool wantsSize;
    private bool[NodeKind] included;

    private void parseConfig()
    {
        if (included.length) return;   // parse once
        foreach (tok; this.nodes.split(","))
            included[kindFromName(tok)] = true;
        included[NodeKind.module_] = true;   // modules are always cluster anchors
        wantsSize = this.metrics.split(",").canFind("size");
    }

    protected override bool wantNode(NodeKind k)
    {
        parseConfig();
        return (k in included) !is null;
    }

    protected override bool wantSize() { parseConfig(); return wantsSize; }

    protected override void onComplete()
    {
        parseConfig();

        auto f = File(this.path, "w");
        f.writeln("digraph {");
        f.writeln("    compound=true;");

        // one cluster per module, with its materialized child nodes inside
        foreach (modId, ref mm; graph.modules)
        {
            f.writefln("    subgraph \"cluster_%X\" {", cast(size_t)modId);

            auto mnode = modId in graph.nodes;
            f.writefln("        label=\"%s\";", mnode ? mnode.name : "");

            f.writef("        \"%X\" [root=%d", cast(size_t)modId, mm.isRoot ? 1 : 0);
            if (wantsSize && mnode) f.writef(",selfsize=%d", mnode.selfSize);
            foreach (k, cnt; mm.counts)
                f.writef(",n_%s=%d", kindName(k), cnt);
            if (mm.isRoot) f.write(",shape=doubleoctagon");
            f.writeln("];");

            foreach (ref e; graph.edges)
            {
                if (e.isImport || e.from !is modId) continue;
                if (auto cn = e.to in graph.nodes)
                    f.writefln("        \"%X\" [label=\"%s\"];",
                        cast(size_t)e.to, cn.name);
            }

            f.writeln("    }");
        }

        // inter-module dependency edges (anchor to target cluster)
        foreach (ref e; graph.edges)
        {
            if (!e.isImport) continue;
            f.writef("    \"%X\" -> \"%X\" [lhead=\"cluster_%X\"",
                cast(size_t)e.from, cast(size_t)e.to, cast(size_t)e.to);
            if (e.isPublicImport) f.write(",pubimport=1");
            f.writeln("];");
        }

        f.writeln("}");
    }

}
