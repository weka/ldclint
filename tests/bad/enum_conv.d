// RUN: env LDCLINT_FLAGS="-Wenum-conv" ldc2 -wi -c %s -o- --plugin=libldclint.so 2>&1 | FileCheck --implicit-check-not=Warning %s

enum A { a1, a2 }
enum B { b1, b2 }

// CHECK-DAG: enum_conv.d([[@LINE+1]]): Warning: Implicit conversion merges different enum types `A` and `B`
auto foo(bool cond, A a, B b) { return cond ? a : b; }
