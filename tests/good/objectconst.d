// RUN: env LDCLINT_FLAGS="-Wno-all -Wsuspicious-objectconst" ldc2 -w -c %s -o- --plugin=libldclint.so

// Methods that are const should not warn
class ConstClass
{
    override size_t toHash() const nothrow @safe
    {
        return 0;
    }

    override bool opEquals(Object other) const
    {
        return true;
    }

    override string toString() const
    {
        return "foo";
    }
}

// Struct with const methods
struct ConstStruct
{
    size_t toHash() const nothrow @safe
    {
        return 0;
    }

    bool opEquals(const ConstStruct other) const
    {
        return true;
    }

    string toString() const
    {
        return "bar";
    }
}

// Empty struct - no warning
struct Empty {}
