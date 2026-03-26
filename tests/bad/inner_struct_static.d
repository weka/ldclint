// RUN: env LDCLINT_FLAGS="-Winner-struct-static" ldc2 -wi -c %s -o- --plugin=libldclint.so 2>&1 | FileCheck --implicit-check-not=Warning %s

void foo()
{
    // CHECK-DAG: inner_struct_static.d(6): Warning: Struct `S` may generate an hidden context pointer
    struct S
    {
        int x;
        int doubled() { return x * 2; }
    }
    S s;
    s.x = 1;

    // this is fine because it explicitly uses outer context
    struct S2
    {
        int x2;
        int doubled2() { return x2 * s.x; }
    }
    S2 s2;
    s2.x2 = 1;

    // this is fine now with static
    static struct S3
    {
        int x3;
        int doubled3() { return x3 * 2; }
    }
    S3 s3;
    s3.x3 = 1;
}
