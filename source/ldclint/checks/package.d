module ldclint.checks;

import ldclint.utils.visitor;
import ldclint.utils.querier;

import std.typecons;

import DMD    = ldclint.dmd;
import DParse = ldclint.dparse;

struct Parameter
{
    import std.sumtype : SumType;
    alias Value = SumType!(string, real, long, bool);

    enum Type
    {
        string,
        number,
        integer,
        boolean,
    }

    string name;
    Type type;
    Nullable!Value defaultValue;

    this(string name, Type type)
    {
        this.name = name;
        this.type = type;
    }

    static foreach(T; Value.Types)
    {
        this(string name, Type type, T defaultValue)
        {
            this.name = name;
            this.type = type;
            this.defaultValue = nullable(Value(defaultValue));
        }
    }
}

struct Metadata
{
    /// group of the check (null if ungrouped)
    string group;
    /// name of the check
    string name;

    @safe pure
    string fullName() const scope
    {
        if (group is null) return name;
        return group ~ "-" ~ name;
    }

    /// check runs by default
    Flag!"byDefault" byDefault;

    /// parameters of the check
    Parameter[] parameters = [];

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

    static foreach(param; metadata.parameters)
    {
        static auto getParameter(string name : param.name)()
        {
            static if(param.type == Parameter.Type.string) alias T = string;
            else static if(param.type == Parameter.Type.number) alias T = real;
            else static if(param.type == Parameter.Type.integer) alias T = long;
            else static if(param.type == Parameter.Type.boolean) alias T = bool;
            else static assert(0, "unsupported parameter type");

            __gshared Nullable!T value;

            if (value.isNull)
            {
                import ldclint.options : options;
                import std.sumtype : match;
                value = options.getParameters(metadata.fullName)[param.name].match!(
                    (T v) => nullable(v),
                    (_) => assert(0),
                );
            }

            return value.get;
        }

        mixin("alias ", param.name, " = getParameter!\"", param.name, "\";");
    }

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
