// RUN: rm -f %t.blame.log
// RUN: env LDCLINT_FLAGS="-Wno-all -Wtool-blame=path=%t.blame.log" ldc2 -w -c %s -o- --plugin=libldclint.so
struct S { int a; }
void f() {}
