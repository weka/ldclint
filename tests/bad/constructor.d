// RUN: env LDCLINT_FLAGS="-Wno-all -Wstyle-duplicate-ctor" ldc2 -wi -c %s -o- --plugin=libldclint.so 2>&1 | FileCheck %s

// CHECK: Warning: Class has both a zero-argument constructor and a constructor with all default arguments
class Cat
{
    this() {}
    this(string name = "kittie") {}
}
