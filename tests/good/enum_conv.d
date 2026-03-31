// RUN: env LDCLINT_FLAGS="-Wenum-conv" ldc2 -w -c %s -o- --plugin=libldclint.so

enum A { a1, a2 }
enum B { b1, b2 }

// same enum type is fine
auto foo(bool cond, A a1, A a2) { return cond ? a1 : a2; }

// explicit cast removes enum type — no warning
auto bar(bool cond, A a, B b) { return cond ? cast(int) a : cast(int) b; }

// non-enum types are fine
auto baz(bool cond, int x, int y) { return cond ? x : y; }
