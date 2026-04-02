// RUN: env LDCLINT_FLAGS="-Wno-all -Wforbid-trusted-block" ldc2 -wi -c %s -o- --plugin=libldclint.so 2>&1 | FileCheck %s

// CHECK-DAG: trust_scope.d(4): Warning: Avoid `@trusted` blocks; mark individual functions `@trusted` instead.
@trusted {
    void scopedFunc1() {}
    void scopedFunc2() {}
}

struct S
{
    // CHECK-DAG: trust_scope.d(12): Warning: Avoid `@trusted` blocks; mark individual functions `@trusted` instead.
    @trusted:
    void method() {}
}
