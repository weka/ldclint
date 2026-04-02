// RUN: env LDCLINT_FLAGS="-Wno-all -Wsuspicious-length-subtraction" ldc2 -wi -c %s -o- --plugin=libldclint.so 2>&1 | FileCheck %s

// CHECK: Warning: Unsigned subtraction from `.length` may wrap around to `size_t.max`.
void testLengthSubtraction(int[] a, size_t i)
{
    if (i < a.length - 1) {}
}
