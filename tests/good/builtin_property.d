// RUN: env LDCLINT_FLAGS="-Wno-all -Wforbid-shadowing" ldc2 -w -c %s -o- --plugin=libldclint.so

struct S
{
    // regular member names should not warn
    int x;
    int value;
    void foo() {}
}

// module-level names should not warn
int init;
int sizeof;
