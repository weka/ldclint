// RUN: env LDCLINT_FLAGS="-Wempty-block" ldc2 -w -c %s -o- --plugin=libldclint.so

void foo(bool cond)
{
    // normal if-else should not warn
    if (cond)
    {
        int x = 1;
    }
    else
    {
        int y = 2;
    }

    // if without else is fine when body is non-empty
    if (cond)
    {
        int z = 3;
    }
}
