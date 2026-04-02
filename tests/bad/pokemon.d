// RUN: env LDCLINT_FLAGS="-Wno-all -Wsuspicious-generic-catch" ldc2 -wi -c %s -o- --plugin=libldclint.so 2>&1 | FileCheck %s

void testCatchError()
{
    // CHECK-DAG: pokemon.d(7): Warning: Catching a non-exception throwable `Error`.
    try { }
    catch (Error e) { }
}

void testCatchThrowable()
{
    // CHECK-DAG: pokemon.d(15): Warning: Catching a non-exception throwable `Throwable`.

    try { }
    catch (Throwable e) { }
}
