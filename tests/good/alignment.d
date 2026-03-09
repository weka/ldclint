// RUN: ldc2 -w -c %s -o- --plugin=libldclint.so

// @nogc exempts misaligned pointers from warning
struct SafeAligned1
{
    align(1) @nogc int* p;
}

// non-pointer types with low alignment are fine
struct SafeAligned2
{
    align(1) int x;
    align(2) float y;
}

// default alignment is fine for pointers
struct SafeAligned3
{
    int* p;
    void*[] arr;
}
