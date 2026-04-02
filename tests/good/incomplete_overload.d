// RUN: env LDCLINT_FLAGS="-Wno-all -Wsuspicious-overload" ldc2 -w -c %s -o- --plugin=libldclint.so

// Has both opEquals and toHash - no warning
class Chimp
{
    bool opEquals(const Chimp other) const
    {
        return true;
    }

    override size_t toHash() const nothrow @safe
    {
        return 0;
    }
}

// Has neither opEquals nor toHash - no warning
struct Bee
{
    int x;
}

// Has opCmp only - no warning (uses default equals and hash)
struct Ant
{
    int opCmp(const Ant other) const
    {
        return 0;
    }
}

// @disable toHash doesn't count
struct Fox
{
    @disable size_t toHash() const nothrow @safe;
}
