// RUN: env LDCLINT_FLAGS="-Wno-all -Wexplicit-static" ldc2 -w -c %s -o- --plugin=libldclint.so

// top-level struct should not warn
struct TopLevel
{
    int x;
}

// explicitly static nested struct should not warn
void foo()
{
    static struct S
    {
        int x;
    }
    S s;
    s.x = 1;
}
