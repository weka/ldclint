// RUN: env LDCLINT_FLAGS="-Wno-all -Wforbid-atproperty -Wunused-private -Wredundant -Wparser" ldc2 -w -c %s -o- --plugin=libldclint.so

private int foo(int p1, int p2)
{
    return p1 + p2;
}

int bar(int p1)
{
    return foo(p1, p1 * 2);
}

void barno(int) {}

__gshared int globalFoo;

// block with a function — static has different meaning for the function, so
// variables in the same block are not flagged even with __gshared
struct GoodBlockGsharedStatic {
    __gshared static:
    int x;
    void method() {}
}
