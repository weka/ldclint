// RUN: env LDCLINT_FLAGS="-Wempty-block" ldc2 -wi -c %s -o- --plugin=libldclint.so 2>&1 | FileCheck --implicit-check-not=Warning %s

void foo(bool cond)
{
    // CHECK-DAG: empty_block.d(6): Warning: Empty `if` body with non-empty `else`
    if (cond)
    {
    }
    else
    {
        int x = 1;
    }

    // CHECK-DAG: empty_block.d(20): Warning: Empty `else` body
    if (cond)
    {
        int y = 2;
    }
    else
    {
    }

    // CHECK-DAG: empty_block.d(24): Warning: Empty `if` body with no `else`
    if (cond)
    {
    }
}
