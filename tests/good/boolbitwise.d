// RUN: env LDCLINT_FLAGS="-Wno-all -Wmisuse-bitwise" ldc2 -w -c %s -o- --plugin=libldclint.so

// bitwise operations on integers should not warn

int foo(int a, int b)
{
    auto r1 = a & b;
    auto r2 = a | b;
    auto r3 = ~a;
    return r1 + r2 + r3;
}
