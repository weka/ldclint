// RUN: env LDCLINT_FLAGS="-Wnegate-unsigned" ldc2 -w -c %s -o- --plugin=libldclint.so

// negating signed integers is fine
int foo(int a)
{
    return -a;
}

// negating unsigned literals is fine (common pattern)
uint bar()
{
    return -1u;
}

// explicit cast is fine
uint baz(uint a)
{
    return cast(uint)-cast(int)a;
}
