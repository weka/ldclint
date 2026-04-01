module ldclint.checks.enum_conv;

import ldclint.utils.querier : Querier, querier;
import ldclint.utils.report;

import DMD = ldclint.dmd;

import std.typecons : No, Yes, Flag;

enum Metadata = imported!"ldclint.checks".Metadata(
    "enum-conv",
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

    override void visit(Querier!(DMD.CondExp) e)
    {
        super.visit(e);

        if (!e.isValid()) return;
        if (!e.isResolved()) return;

        auto t1 = getOriginalType(cast(DMD.Expression) e.e1);
        auto t2 = getOriginalType(cast(DMD.Expression) e.e2);

        if (t1 is null || t2 is null) return;

        // At least one must be an enum
        auto te1 = t1.isTypeEnum();
        auto te2 = t2.isTypeEnum();
        if (te1 is null && te2 is null) return;

        // Same enum type is fine
        if (te1 !is null && te2 !is null && te1.sym is te2.sym) return;

        warning(e.loc,
            "Implicit conversion merges different types `%s` and `%s`",
            t1.toChars(), t2.toChars());
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
        // Ideally we would correlate with the libdparse AST which preserves
        // CastExpression nodes, but that infrastructure doesn't exist yet.
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

    /// Get the original type of an expression, unwrapping implicit CastExp
    /// inserted by typeMerge to recover the pre-conversion type.
    private static DMD.Type getOriginalType(DMD.Expression e)
    {
        if (e is null) return null;

        // If typeMerge already lowered, unwrap CastExp to get original type
        if (auto ce = e.isCastExp())
        {
            auto inner = getOriginalType(ce.e1);
            if (inner !is null) return inner;
        }

        return e.type;
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
