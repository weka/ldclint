// RUN: env LDCLINT_FLAGS="-Wno-all -Wforbid-missing-return" ldc2 -w -c %s -o- --plugin=libldclint.so

// auto function WITH return - no warning
auto doStuffWithReturn()
{
    return 42;
}

// Explicit void function - no warning
void explicitVoid()
{
}
