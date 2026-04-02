// RUN: env LDCLINT_FLAGS="-Wno-all -Wsuspicious-assert" ldc2 -wi -c %s -o- --plugin=libldclint.so 2>&1 | FileCheck %s

void testUselessAssert()
{
    // CHECK-DAG: useless_assert.d(6): Warning: Assert condition is a compile-time constant and is always true; did you mean to assert a variable?
    assert(true);
    // CHECK-DAG: useless_assert.d(8): Warning: Assert condition is a compile-time constant and is always true; did you mean to assert a variable?
    assert(1);
    // CHECK-DAG: useless_assert.d(10): Warning: Assert condition is a compile-time constant and is always true; did you mean to assert a variable?
    assert(42);
}
