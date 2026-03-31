module ldclint.checks;

import ldclint.utils.visitor;
import ldclint.utils.querier;

import std.typecons;

import DMD    = ldclint.dmd;
import DParse = ldclint.dparse;

struct Metadata
{
    /// name of the check
    string name;

    @safe pure
    string varName() const scope
    {
        import std.array : replace;
        return name.replace("-", "_");
    }

    /// check runs by default
    Flag!"byDefault" byDefault;

    /// check runs on all modules
    Flag!"allModules" allModules = No.allModules;

    /// run priority
    ubyte priority = 0;
}

class AbstractCheck : Visitor
{
    ///
    alias visit = Visitor.visit;

    /// module currently visiting
    DMD.Module currentModule = null;

    override void visit (Querier!(DMD.Module) m)
    {
        // lets skip invalid modules
        if (!m.isValid()) return;

        auto prevMod = this.currentModule;

        this.currentModule = m;
        scope(exit) this.currentModule = prevMod;

        super.visit(m);
    }

    override void visit (Querier!(DMD.Dsymbol) s)
    {
        // lets skip invalid symbols
        if (!s.isValid()) return;

        super.visit(s);
        debug (ast) stderr.writefln("! Unhandled symbol `%s` of kind '%s'", fromStringz(s.toChars()), fromStringz(s.kind));
    }

    override void visit (Querier!(DMD.Expression) e)
    {
        // lets skip invalid expression
        if (!e.isValid()) return;

        super.visit(e);
        debug (ast) stderr.writefln("! Unhandled expression `%s` of kind '%s'", fromStringz(e.toChars()), e.op);
    }

    override void visit (Querier!(DMD.Statement) s)
    {
        // lets skip invalid statements
        if (!s.isValid()) return;

        super.visit(s);
        debug (ast) stderr.writefln("! Unhandled statement `%s` of type '%s'", fromStringz(s.toChars()), s.stmt);
    }

    override void visit (Querier!(DMD.Type) t)
    {
        // lets skip invalid types
        if (!t.isValid()) return;

        super.visit(t);
        debug (ast) stderr.writefln("! Unhandled type `%s` of kind '%s'", fromStringz(t.toChars()), fromStringz(t.kind()));
    }

    override void visit (Querier!(DMD.FuncDeclaration) fd)
    {
        // lets skip invalid functions
        if (!fd.isValid()) return;

        super.visit(fd);
    }

    override void visit(Querier!(DMD.IntegerExp))         { /* skip */ }
    override void visit(Querier!(DMD.RealExp))            { /* skip */ }
    override void visit(Querier!(DMD.ComplexExp))         { /* skip */ }
    override void visit(Querier!(DMD.ErrorExp))           { /* skip */ }
    override void visit(Querier!(DMD.Initializer))        { /* skip */ }
    override void visit(Querier!(DMD.Parameter))          { /* skip */ }
    override void visit(Querier!(DMD.TemplateParameter))  { /* skip */ }
    override void visit(Querier!(DMD.Condition))          { /* skip */ }
}

struct CheckInfo {
    /// class info of the check
    ClassInfo classInfo;
    /// metadata of the check
    Metadata metadata;
}

class GenericCheck(Metadata metadata) : AbstractCheck
{
    ///
    alias visit = AbstractCheck.visit;

    override void visit (Querier!(DMD.Module) m)
    {
        // lets skip invalid modules
        if (!m.isValid()) return;

        // lets skip this module if we are already visiting one
        if (!metadata.allModules && currentModule !is null) return;

        super.visit(m);
    }
}

mixin template RegisterCheck(Metadata metadata)
{
    import ldclint.checks : CheckInfo;
    import ldc.attributes : section, assumeUsed;

    @assumeUsed @section("ldclint_checks") align(1)
    __gshared CheckInfo info = CheckInfo(
        typeid(typeof(this)),
        metadata,
    );
}

CheckInfo[] allChecks()
{
    import ldclint.utils.sections : sectionSlice;
    return cast(CheckInfo[])sectionSlice!"ldclint_checks"();
}
