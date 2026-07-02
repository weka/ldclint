module ldclint.checks.tool_blame;

import ldclint.utils.graph;
import ldclint.checks.graph_check : GraphCheck;
import ldclint.checks : Parameter;

import std.typecons : No, Yes;
import std.stdio : File;
import std.array : Appender, appender;
import std.format : formattedWrite;

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
/// Columns (in header order):
///
///   kind   — the symbol's raw DMD kind string (module, struct, class,
///            function, variable, "enum member", "static import", ...).
///   hash   — deterministic content hash of the symbol (folds in name,
///            kind, size, and the parent's hash); stable across runs.
///            Lets downstream tools join rows without depending on pointer
///            values.
///   addr   — the AST node pointer in hex; stable for the duration of the
///            compile.
///   phash  — the parent symbol's hash (0 at module root).
///   paddr  — the parent AST node pointer in hex (0 at module root).
///   file   — source path; empty when the symbol shares its module's file.
///   line   — line number.
///   name   — symbol name; empty for unnamed aggregates.
///   size   — `__traits(classInstanceSize)` of the AST node the frontend
///            allocated (compiler-memory footprint, not the runtime type
///            size).
final class Check : GraphCheck!Metadata
{
    mixin imported!"ldclint.checks".RegisterCheck!Metadata;
    alias visit = GraphCheck!Metadata.visit;

    // tool-blame materializes every kind, attaches sizes, and streams rows
    // instead of accumulating a graph.
    protected override bool wantNode(NodeKind) { return true; }
    protected override bool wantSize() { return true; }

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

    private Appender!(char[]) writeBuffer;
    private enum size_t flushThreshold = 64 * 1024 * 1024;

    /// Reproduces the deterministic per-symbol hash chain the old pushNode
    /// built: each node's hash folds in its parent's hash. Parent is emitted
    /// before child (pre-order), so the lookup is always populated.
    private size_t[void*] hashOfNode;

    protected override void onNode(in NodeEvent e)
    {
        auto pid = cast(void*)e.parentId;
        size_t parentHash = pid is null ? 0 : hashOfNode.get(pid, 0);

        auto hash = hashOf(e.name, hashOf(":",
                           hashOf(e.rawKind,
                           hashOf(e.selfSize,
                           hashOf("::", parentHash)))));
        hashOfNode[cast(void*)e.id] = hash;

        writeBuffer.formattedWrite!"%s,0x%X,0x%X,0x%X,0x%X,%s,%d,%s,%d\n"(
            e.rawKind,
            hash,
            cast(size_t)e.id,
            parentHash,
            cast(size_t)e.parentId,
            csvField(e.file),
            e.line,
            csvField(e.name),
            e.selfSize
        );

        if (writeBuffer[].length >= flushThreshold)
            flushBuffer();
    }

    protected override void onEdge(in EdgeEvent) { /* blame ignores edges */ }

    /// Fired at the end of the outermost visit(Module) (after the amodules
    /// walk) — drain whatever rows remain. LDC plugins don't reliably run
    /// D-runtime exit hooks under dlclose, but this hook always executes.
    protected override void onComplete() { flushBuffer(); }

    void flushBuffer()
    {
        if (writeBuffer[].length == 0) return;
        auto f = output();
        f.lock();
        scope(exit) f.unlock();
        f.rawWrite(writeBuffer[]);
        f.flush();
        writeBuffer.clear();
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
