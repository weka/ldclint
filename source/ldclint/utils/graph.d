module ldclint.utils.graph;

import std.bitmanip : bitfields;

/// Categorization of a materialized AST node. Independent of the raw
/// `Dsymbol.kind()` string (which tool-blame still emits verbatim).
enum NodeKind
{
    module_, struct_, class_, interface_, union_, enum_, enumMember,
    field, variable, function_, alias_, template_, templateInstance,
    mixinTemplate, import_, other
}

/// Stored per materialized symbol. Kept minimal: module-only fields live
/// in `ModuleMeta`, and cross-file locations in the `fileOverride` table.
struct Node
{
    void*          id;        /// stable AST pointer, dedup key
    NodeKind       kind;
    const(char)[]  name;
    uint           line;
    size_t         selfSize;  /// 0 unless size metric requested
}

/// Side-table entry; only module nodes get one.
struct ModuleMeta
{
    const(char)[]  file;      /// module source path; inherited by children
    uint[NodeKind] counts;    /// collapsed counts for child kinds NOT materialized
    mixin(bitfields!(bool, "isRoot", 1, uint, "", 7));
}

/// A directed edge. `isImport` discriminates the relation (0 contains,
/// 1 imports). The two import flags are meaningful only when isImport is set.
struct Edge
{
    void* from;
    void* to;
    mixin(bitfields!(
        bool, "isImport",       1,
        bool, "isPublicImport", 1,
        bool, "isStaticImport", 1,
        uint, "",               5));
}

/// The accumulated graph (default hook target).
struct Graph
{
    Node[void*]        nodes;
    ModuleMeta[void*]  modules;      /// keyed by module node id
    const(char)[][void*] fileOverride; /// symbols whose file != their module's
    Edge[]             edges;
}

/// Transient event passed to the hooks (not stored as-is). Carries the raw
/// kind string so tool-blame can reproduce its exact CSV / hash.
struct NodeEvent
{
    void*          id;
    void*          parentId;
    NodeKind       kind;
    const(char)[]  rawKind;   /// verbatim Dsymbol.kind()
    const(char)[]  name;
    const(char)[]  file;      /// resolved source path ("" if == module file)
    uint           line;
    size_t         selfSize;
    bool           isModule;
    bool           isRoot;    /// modules only
}

struct EdgeEvent
{
    void* from;
    void* to;
    bool  isImport;
    bool  isPublicImport;
    bool  isStaticImport;
}

/// Returns the stable short name for a NodeKind (used in DOT attributes and
/// CSV columns). Exhaustive final switch -- the compiler enforces coverage.
string kindName(NodeKind k) @safe pure nothrow
{
    final switch (k)
    {
        case NodeKind.module_:          return "module";
        case NodeKind.struct_:          return "struct";
        case NodeKind.class_:           return "class";
        case NodeKind.interface_:       return "interface";
        case NodeKind.union_:           return "union";
        case NodeKind.enum_:            return "enum";
        case NodeKind.enumMember:       return "enum_member";
        case NodeKind.field:            return "field";
        case NodeKind.variable:         return "variable";
        case NodeKind.function_:        return "function";
        case NodeKind.alias_:           return "alias";
        case NodeKind.template_:        return "template";
        case NodeKind.templateInstance: return "template_instance";
        case NodeKind.mixinTemplate:    return "mixin";
        case NodeKind.import_:          return "import";
        case NodeKind.other:            return "other";
    }
}

/// Map a short kind name back to a NodeKind. Unknown names -> other.
/// Inverse of `kindName`; accepts the same tokens it emits.
NodeKind kindFromName(const(char)[] s) @safe pure nothrow
{
    switch (s)
    {
        case "module":            return NodeKind.module_;
        case "struct":            return NodeKind.struct_;
        case "class":             return NodeKind.class_;
        case "interface":         return NodeKind.interface_;
        case "union":             return NodeKind.union_;
        case "enum":              return NodeKind.enum_;
        case "enum_member":       return NodeKind.enumMember;
        case "field":             return NodeKind.field;
        case "variable":          return NodeKind.variable;
        case "function":          return NodeKind.function_;
        case "alias":             return NodeKind.alias_;
        case "template":          return NodeKind.template_;
        case "template_instance": return NodeKind.templateInstance;
        case "mixin":             return NodeKind.mixinTemplate;
        case "import":            return NodeKind.import_;
        default:                  return NodeKind.other;
    }
}

/// Map a raw `Dsymbol.kind()` string to a NodeKind. Unknown -> other.
NodeKind classify(const(char)[] raw) @safe pure nothrow
{
    switch (raw)
    {
        case "module":         return NodeKind.module_;
        case "struct":         return NodeKind.struct_;
        case "class":          return NodeKind.class_;
        case "interface":      return NodeKind.interface_;
        case "union":          return NodeKind.union_;
        case "enum":           return NodeKind.enum_;
        case "enum member":    return NodeKind.enumMember;
        case "field":          return NodeKind.field;
        case "variable":       return NodeKind.variable;
        case "function":       return NodeKind.function_;
        case "alias":          return NodeKind.alias_;
        case "template":       return NodeKind.template_;
        case "template instance": return NodeKind.templateInstance;
        case "mixin":          return NodeKind.mixinTemplate;
        case "import":         return NodeKind.import_;
        case "static import":  return NodeKind.import_;
        default:               return NodeKind.other;
    }
}

/// Returns a component id for each node that participates in an import edge.
/// Nodes absent from the result belong to no cycle. Tarjan SCC over import
/// edges only. Nodes in a component of size > 1 (or a self-loop, which we
/// never emit) are cyclic. Used by import-cycle. Deterministic given
/// insertion order.
///
/// Takes `ref Graph` rather than `ref const Graph`: LDC propagates the const
/// transitively so `edges[].from/.to` would become `const(void*)`, which
/// cannot key the mutable `void*` AAs we build below. For the same reason the
/// AA-key loop variable needs a `cast(void*)` (AA-key iteration yields a const
/// key even over a mutable AA).
size_t[void*] stronglyConnected(ref Graph g)
{
    // Build import adjacency.
    void*[][void*] adj;
    foreach (ref e; g.edges)
        if (e.isImport)
            adj[e.from] ~= e.to;

    size_t[void*] index, low, comp;
    bool[void*] onStack;
    void*[] stack;
    size_t counter = 0, ncomp = 0;

    void strongConnect(void* v)
    {
        index[v] = counter; low[v] = counter; counter++;
        stack ~= v; onStack[v] = true;

        if (auto succs = v in adj)
            foreach (w; *succs)
            {
                if (w !in index)
                {
                    strongConnect(w);
                    if (low[w] < low[v]) low[v] = low[w];
                }
                else if (onStack.get(w, false) && index[w] < low[v])
                    low[v] = index[w];
            }

        if (low[v] == index[v])
        {
            while (true)
            {
                auto w = stack[$ - 1];
                stack = stack[0 .. $ - 1];
                onStack[w] = false;
                comp[w] = ncomp;
                if (w is v) break;
            }
            ncomp++;
        }
    }

    // cast: AA-key iteration yields a const key even over a mutable AA.
    foreach (v, _; adj)
        if (v !in index)
            strongConnect(cast(void*) v);

    return comp;
}
