// RUN: env LDCLINT_FLAGS="-Wno-all -Wmisuse" ldc2 -w -c %s -o- --plugin=libldclint.so

struct S { int x; }

class C { int y; }

void foo()
{
    S s;
    destroy(s);

    C c;
    destroy(c);

    int x;
    destroy(x);
}
