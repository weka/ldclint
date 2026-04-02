// RUN: env LDCLINT_FLAGS="-Wno-all -Wforbid-vcall-ctor" ldc2 -w -c %s -o- --plugin=libldclint.so

// Private method called from constructor - not virtual, no warning
class PrivateCall
{
    this()
    {
        foo();
    }

    private void foo() {}
}

// Final method called from constructor - no warning
class FinalCall
{
    this()
    {
        foo();
    }

    final void foo() {}
}

// Final class - methods can't be overridden, no warning
final class FinalClass
{
    this()
    {
        foo();
    }

    void foo() {}
}

// Static method - no virtual dispatch
class StaticCall
{
    this()
    {
        foo();
    }

    static void foo() {}
}
