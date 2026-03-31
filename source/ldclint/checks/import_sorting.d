module ldclint.checks.import_sorting;

import ldclint.utils.querier : Querier, querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons : No, Yes, Flag;

enum Metadata = imported!"ldclint.checks".Metadata(
    "import-sorting",
    No.byDefault,
);

final class Check : imported!"ldclint.checks".GenericCheck!Metadata
{
    mixin imported!"ldclint.checks".RegisterCheck!Metadata;

    alias visit = imported!"ldclint.checks".GenericCheck!Metadata.visit;

    override void visit(Querier!(DMD.Module) m)
    {
        if (!m.isValid()) return;

        checkImportSorting(m);

        super.visit(m);
    }

    /// Scan module members for contiguous import blocks and check sorting.
    private void checkImportSorting(Querier!(DMD.Module) m)
    {
        if (m.members is null) return;

        // collect all top-level imports with their names and locations
        static struct ImportInfo
        {
            const(char)[] name;
            uint line;
            DMD.Loc loc;
        }

        ImportInfo[] currentBlock;

        void checkBlock()
        {
            if (currentBlock.length < 2) { currentBlock.length = 0; return; }

            // check if sorted
            for (size_t i = 1; i < currentBlock.length; i++)
            {
                if (currentBlock[i].name < currentBlock[i-1].name)
                {
                    warning(currentBlock[i].loc,
                        "Imports are not sorted; `%s` should come before `%s`",
                        currentBlock[i].name.ptr, currentBlock[i-1].name.ptr);
                    break;
                }
            }
            currentBlock.length = 0;
        }

        uint lastImportLine = 0;

        foreach (sym; *m.members)
        {
            if (sym is null) continue;

            // check if this is an import
            auto imp = sym.isImport();
            if (imp is null)
            {
                // also check AttribDeclarations which may contain imports
                // (e.g. public: import ...)
                // For simplicity, end the block on non-import declarations
                checkBlock();
                lastImportLine = 0;
                continue;
            }

            // skip the implicit object import
            if (imp.id == DMD.Id.object) continue;

            uint line = imp.loc.linnum;

            // check if this import is contiguous with the previous one
            if (currentBlock.length > 0 && line != lastImportLine + 1)
            {
                checkBlock();
            }

            // build the full module path name
            auto name = getImportPath(imp);
            currentBlock ~= ImportInfo(name, line, imp.loc);
            lastImportLine = line;
        }

        checkBlock();
    }

    private static const(char)[] getImportPath(DMD.Import imp)
    {
        const(char)[] result;

        foreach (pkg; imp.packages)
        {
            if (result.length) result ~= ".";
            result ~= pkg.toString();
        }

        if (result.length) result ~= ".";
        result ~= imp.id.toString();

        return result;
    }

    // avoid false positives inside uninstantiated templates
    override void visit(Querier!(DMD.TemplateDeclaration)) { /* skip */ }
}
