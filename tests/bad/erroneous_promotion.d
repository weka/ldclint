// RUN: env LDCLINT_FLAGS="-Werroneous-promotion" ldc2 -wi -c %s -o- --plugin=libldclint.so 2>&1 | FileCheck --implicit-check-not=Warning %s

float foo(int a, int b)
{
    // CHECK-DAG: erroneous_promotion.d(6): Warning: Integer division cast to floating-point
    return cast(float)(a / b);
}

double bar(int a, int b)
{
    // CHECK-DAG: erroneous_promotion.d(12): Warning: Integer division cast to floating-point
    return cast(double)(a / b);
}
