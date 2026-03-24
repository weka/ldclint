// RUN: env LDCLINT_FLAGS="-Wnegate-unsigned" ldc2 -wi -c %s -o- --plugin=libldclint.so 2>&1 | FileCheck --implicit-check-not=Warning %s

uint foo(uint a)
{
    // CHECK-DAG: negate_unsigned.d(6): Warning: Negating unsigned integer
    return -a;
}
