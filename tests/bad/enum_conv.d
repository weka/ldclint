// RUN: env LDCLINT_FLAGS="-Wenum-conv" ldc2 -wi -c %s -o- --plugin=libldclint.so 2>&1 | FileCheck --implicit-check-not=Warning %s

enum A { a1, a2 }
enum B { b1, b2 }

// CHECK-DAG: enum_conv.d([[@LINE+1]]): Warning: Implicit conversion merges different types `A` and `B`
auto foo1(bool cond, A a, B b) { return cond ? a : b; }
// CHECK-DAG: enum_conv.d([[@LINE+1]]): Warning: Implicit conversion merges different types `int` and `B`
auto foo2(bool cond, int a, B b) { return cond ? a : b; }
// CHECK-DAG: enum_conv.d([[@LINE+1]]): Warning: Implicit conversion merges different types `A` and `int`
auto foo3(bool cond, A a, int b) { return cond ? a : b; }

// CHECK-DAG: enum_conv.d([[@LINE+1]]): Warning: Implicit conversion merges different types `A` and `int`
auto foo4(bool cond, A a) { return cond ? a : 0; }

// CHECK-DAG: enum_conv.d([[@LINE+1]]): Warning: Implicit conversion merges different types `A` and `int`
int bar1(A a) { return a; }
// CHECK-DAG: enum_conv.d([[@LINE+1]]): Warning: Implicit conversion merges different types `A` and `int`
int bar2() { A a = A.a1; return a; }
