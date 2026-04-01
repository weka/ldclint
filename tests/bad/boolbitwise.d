// RUN: env LDCLINT_FLAGS="-Wno-all -Wmisuse-bitwise" ldc2 -wi -c %s -o- --plugin=libldclint.so 2>&1 | FileCheck --implicit-check-not=Warning %s

bool foo(bool a, bool b)
{
    // CHECK-DAG: boolbitwise.d(6): Warning: Avoid bitwise operations with boolean `a`
    auto r1 = a & b;

    // CHECK-DAG: boolbitwise.d(9): Warning: Avoid bitwise operations with boolean `a`
    auto r2 = a | b;

    return r1 != 0 || r2 != 0;
}
