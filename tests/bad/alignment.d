// RUN: ldc2 -wi -c %s -o- --plugin=libldclint.so 2>&1 | FileCheck --implicit-check-not=Warning %s

struct BadAligned1
{
    // CHECK-DAG: alignment.d(6): Warning: Variable `p` is misaligned and contains pointers. Use `@nogc` to be explicit.
    align(1) int* p;
}

struct BadAligned2
{
    // CHECK-DAG: alignment.d(12): Warning: Variable `arr` is misaligned and contains pointers. Use `@nogc` to be explicit.
    align(1) void*[] arr;
}
