module ldclint.checks.implicit_enum_return;

import ldclint.utils.querier : Querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons : No, Yes, Flag;

enum Metadata = imported!"ldclint.checks".Metadata(
    "implicit",
    "enum-return",
    No.byDefault,
);

final class Check : imported!"ldclint.checks".GenericCheck!Metadata
{
    mixin imported!"ldclint.checks".RegisterCheck!Metadata;

    alias visit = imported!"ldclint.checks".GenericCheck!Metadata.visit;

    private DMD.FuncDeclaration currentFunc;

    override void visit(Querier!(DMD.FuncDeclaration) fd)
    {
        if (!fd.isValid()) return;

        auto prev = this.currentFunc;
        this.currentFunc = fd.astNode;
        scope(exit) this.currentFunc = prev;

        super.visit(fd);
    }

    override void visit(Querier!(DMD.FuncLiteralDeclaration) fd)
    {
        auto prev = this.currentFunc;
        this.currentFunc = fd.astNode;
        scope(exit) this.currentFunc = prev;

        super.visit(fd);
    }

    override void visit(Querier!(DMD.ReturnStatement) rs)
    {
        super.visit(rs);

        if (!rs.isValid()) return;
        if (currentFunc is null) return;

        auto exp = rs.exp;
        if (exp is null) return;

        // Workaround: DMD strips explicit CastExp from return expressions
        // during semantic analysis, making `return cast(T)x` indistinguishable
        // from `return x` in the AST. To avoid false positives, check the raw
        // source text for an explicit cast between `return` and the expression.
        if (exp.isCastExp()) return;
        if (sourceHasCast(rs.loc, exp.loc)) return;

        auto ft = currentFunc.type;
        if (ft is null) return;
        auto retType = ft.nextOf();
        if (retType is null) return;

        // DMD modifies the expression's type in-place for implicit return
        // conversions, so check the variable's declared type instead.
        DMD.Type expType;
        if (auto ve = exp.isVarExp())
            if (ve.var)
                expType = ve.var.type;
        if (expType is null)
            expType = exp.type;
        if (expType is null) return;

        // At least one must be an enum
        auto retEnum = retType.isTypeEnum();
        auto expEnum = expType.isTypeEnum();
        if (retEnum is null && expEnum is null) return;

        // Same enum type is fine
        if (retEnum !is null && expEnum !is null && retEnum.sym is expEnum.sym) return;

        warning(rs.loc,
            "Implicit conversion merges different types `%s` and `%s`",
            expType.toChars(), retType.toChars());
    }

    /// Check if the source text between two locations contains `cast(`.
    /// Used to detect explicit casts that DMD stripped from the AST.
    private bool sourceHasCast(DMD.Loc from, DMD.Loc to)
    {
        import std.algorithm : canFind;

        if (currentModule is null) return false;
        auto src = cast(const(char)[]) currentModule.src;
        if (src.length == 0) return false;

        auto start = locOffset(src, from);
        auto end = locOffset(src, to);
        if (start >= end || end > src.length) return false;

        return src[start .. end].canFind("cast(");
    }

    /// Convert a Loc (line/column) to a byte offset into the source text.
    private static size_t locOffset(const(char)[] src, DMD.Loc loc)
    {
        size_t offset = 0;
        for (uint line = 1; offset < src.length && line < loc.linnum; offset++)
            if (src[offset] == '\n')
                line++;
        // charnum is 1-based
        if (loc.charnum > 0)
            offset += loc.charnum - 1;
        return offset;
    }

    // avoid false positives inside uninstantiated templates
    override void visit(Querier!(DMD.TemplateDeclaration)) { /* skip */ }
}
