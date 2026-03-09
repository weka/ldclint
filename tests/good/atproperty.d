// RUN: env LDCLINT_FLAGS="-Watproperty" ldc2 -w -c %s -o- --plugin=libldclint.so

// regular functions should not trigger @property warning

int foo(int x) { return x + 1; }

void bar() {}

int baz(int a, int b) { return a + b; }
