// RUN: env LDCLINT_FLAGS="-Watproperty" ldc2 -wi -c %s -o- --plugin=libldclint.so 2>&1 | FileCheck --implicit-check-not=Warning %s

// CHECK-DAG: atproperty.d(4): Warning: Avoid the usage of `@property` attribute
@property int foo() { return 42; }

// CHECK-DAG: atproperty.d(7): Warning: Avoid the usage of `@property` attribute
@property void bar(int x) {}
