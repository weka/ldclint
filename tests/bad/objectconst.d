// RUN: env LDCLINT_FLAGS="-Wno-all -Wsuspicious-objectconst" ldc2 -wi -c %s -o- --plugin=libldclint.so 2>&1 | FileCheck %s

class Foo
{
    // CHECK-DAG: objectconst.d(6): Warning: `toHash` should be marked `const` to work with `const` and `immutable` receivers.
    override size_t toHash() nothrow @safe
    {
        return 0;
    }
}

struct Bar
{
    // CHECK-DAG: objectconst.d(15): Warning: `toString` should be marked `const` to work with `const` and `immutable` receivers.
    string toString()
    {
        return "bar";
    }
}
