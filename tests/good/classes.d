// RUN: env LDCLINT_FLAGS="-Wno-all -Wredundant-final" ldc2 -w -c %s -o- --plugin=libldclint.so

class Foo
{
    final void foo() { bar(); }
    private void bar() {}
}
