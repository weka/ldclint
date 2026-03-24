// RUN: env LDCLINT_FLAGS="-Wdestroy-ptr" ldc2 -wi -c %s -o- --plugin=libldclint.so 2>&1 | FileCheck --implicit-check-not=Warning %s

struct S { int x; }

void foo()
{
    int* p;
    S* sp;

    // CHECK-DAG: destroy_ptr.d(11): Warning: Calling `destroy()` on a pointer destroys the pointer itself, not the pointee
    destroy(p);

    // CHECK-DAG: destroy_ptr.d(14): Warning: Calling `destroy()` on a pointer destroys the pointer itself, not the pointee
    destroy(sp);
}
