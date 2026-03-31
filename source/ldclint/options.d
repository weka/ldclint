module ldclint.options;

import ldclint.checks;

import std.typecons : Flag, Yes, No;

class InvalidOptionsException : Exception
{
    ///
    mixin imported!"std.exception".basicExceptionCtors;
}

struct Options
{
    private bool[string] enabled;
    private Parameter.Value[string][string] params;
    private CheckInfo[string] infoByName;
    private bool initialized;
    private bool parsed;

    void initialize()
    {
        if (initialized) return;
        scope(success) initialized = true;

        foreach (ref info; allChecks())
        {
            infoByName[info.metadata.name] = info;
            enabled[info.metadata.name] = info.metadata.byDefault == Yes.byDefault;
        }
    }

    bool isEnabled(string name)
        in(parsed)
    {
        if (auto p = name in enabled)
            return *p;
        return false;
    }

    Parameter.Value[string] getParameters(string name)
        in(parsed)
    {
        if (auto p = name in params)
            return *p;
        return null;
    }

    void parse(string[] args)
        in(initialized)
    {
        scope(success) parsed = true;

        import std.string : strip, indexOf;

        foreach (arg; args)
        {
            auto a = arg.strip();

            if (a == "-Wall")
            {
                foreach (key; enabled.keys)
                    enabled[key] = true;
            }
            else if (a == "-Wno-all")
            {
                foreach (key; enabled.keys)
                    enabled[key] = false;
            }
            else if (a.length > 5 && a[0 .. 5] == "-Wno-")
            {
                auto name = a[5 .. $];
                if (name !in enabled)
                    throw new InvalidOptionsException("unknown check: " ~ name);
                enabled[name] = false;
            }
            else if (a.length > 2 && a[0 .. 2] == "-W")
            {
                auto rest = a[2 .. $];
                auto eqIdx = rest.indexOf('=');

                if (eqIdx < 0)
                {
                    // Simple: -Wcheck
                    if (rest !in enabled)
                        throw new InvalidOptionsException("unknown check: " ~ rest);
                    enabled[rest] = true;
                }
                else
                {
                    // Parameterized: -Wcheck=param1=x,flag1,param2=y
                    auto name = rest[0 .. eqIdx];
                    if (name !in enabled)
                        throw new InvalidOptionsException("unknown check: " ~ name);
                    enabled[name] = true;
                    parseParams(name, rest[eqIdx + 1 .. $]);
                }
            }
        }

        validate();
    }

    private void parseParams(string name, string paramStr)
    {
        import std.string : indexOf;
        import std.algorithm.iteration : splitter;

        auto meta = infoByName[name].metadata;

        foreach (param; paramStr.splitter(','))
        {
            auto eqIdx = param.indexOf('=');
            if (eqIdx < 0)
            {
                // Flag: treat as key=true
                if (param.length > 0)
                {
                    auto paramMeta = findParam(meta.parameters, param);
                    if (paramMeta is null)
                        throw new InvalidOptionsException(
                            "-W" ~ name ~ ": unknown parameter '" ~ param ~ "'");
                    if (paramMeta.type != Parameter.Type.boolean)
                        throw new InvalidOptionsException(
                            "-W" ~ name ~ ": parameter '" ~ param ~ "' is not a boolean flag");
                    params[name][param] = Parameter.Value(true);
                }
            }
            else
            {
                // Key=value
                auto key = param[0 .. eqIdx];
                auto value = param[eqIdx + 1 .. $];
                if (key.length > 0)
                {
                    auto paramMeta = findParam(meta.parameters, key);
                    if (paramMeta is null)
                        throw new InvalidOptionsException(
                            "-W" ~ name ~ ": unknown parameter '" ~ key ~ "'");
                    params[name][key] = convertValue(*paramMeta, value);
                }
            }
        }
    }

    private void validate()
    {
        foreach (name, isEnabled; enabled)
        {
            if (!isEnabled) continue;

            auto meta = infoByName[name].metadata;
            auto checkParams = &params.require(name, (Parameter.Value[string]).init);

            // Check required params are present
            foreach (ref p; meta.parameters)
            {
                if (p.name !in *checkParams)
                {
                    if (p.defaultValue.isNull)
                        throw new InvalidOptionsException(
                            "-W" ~ name ~ ": missing required parameter '" ~ p.name ~ "'");
                    (*checkParams)[p.name] = p.defaultValue.get;
                }
            }
        }
    }

    private static const(Parameter)* findParam(const Parameter[] parameters, string name)
    {
        foreach (ref p; parameters)
            if (p.name == name)
                return &p;
        return null;
    }

    private static Parameter.Value convertValue(ref const Parameter p, string value)
    {
        import std.conv : to, ConvException;

        final switch (p.type)
        {
            case Parameter.Type.string:
                return Parameter.Value(value);
            case Parameter.Type.boolean:
                if (value != "true" && value != "false")
                    throw new InvalidOptionsException(
                        "parameter '" ~ p.name ~ "': expected 'true' or 'false', got '" ~ value ~ "'");
                return Parameter.Value(value == "true");
            case Parameter.Type.integer:
                try
                    return Parameter.Value(value.to!long);
                catch (ConvException)
                    throw new InvalidOptionsException(
                        "parameter '" ~ p.name ~ "': expected integer, got '" ~ value ~ "'");
            case Parameter.Type.number:
                try
                    return Parameter.Value(value.to!real);
                catch (ConvException)
                    throw new InvalidOptionsException(
                        "parameter '" ~ p.name ~ "': expected number, got '" ~ value ~ "'");
        }
    }
}

__gshared Options options;
