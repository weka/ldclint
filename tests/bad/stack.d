// RUN: env LDCLINT_FLAGS="-Wno-all -Wstack-size" ldc2 -wi -c %s -o- --plugin=libldclint.so 2>&1 | FileCheck --implicit-check-not=Warning %s

void foo()
{
    // CHECK-DAG: stack.d(6): Warning: Stack variable `big` is big (size: 1024, limit: 256)
    byte[1024] big;
    big[0] = 1;
}
