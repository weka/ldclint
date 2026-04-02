// RUN: env LDCLINT_FLAGS="-Wno-all -Wforbid-vcall-ctor" ldc2 -wi -c %s -o- --plugin=libldclint.so 2>&1 | FileCheck %s

// CHECK: Warning: Calling virtual method `foo` in a constructor dispatches to this class, not to any derived class override.
class Bar
{
    this()
    {
        foo();
    }

    public void foo() {}
}
