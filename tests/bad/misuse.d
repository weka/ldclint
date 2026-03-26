// RUN: env LDCLINT_FLAGS="-Wno-all -Wmisuse" ldc2 -wi -c %s -o- --plugin=libldclint.so 2>&1 | FileCheck --implicit-check-not=Warning %s

struct S { int x; }

void foo()
{
    int* p;
    S* sp;

    // CHECK-DAG: misuse.d(11): Warning: Calling `destroy()` on a pointer destroys the pointer itself, not the pointee
    destroy(p);

    // CHECK-DAG: misuse.d(14): Warning: Calling `destroy()` on a pointer destroys the pointer itself, not the pointee
    destroy(sp);
}
