// RUN: env LDCLINT_FLAGS="-Wbuiltin-property" ldc2 -wi -c %s -o- --plugin=libldclint.so 2>&1 | FileCheck --implicit-check-not=Warning %s

struct S
{
    // CHECK-DAG: builtin_property.d(6): Warning: Member `init` shadows built-in `.init` property
    int init;
}

class C
{
    // CHECK-DAG: builtin_property.d(12): Warning: Member `stringof` shadows built-in `.stringof` property
    int stringof;
}
