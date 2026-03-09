// RUN: env LDCLINT_FLAGS="-Wstack" ldc2 -w -c %s -o- --plugin=libldclint.so

// small stack variables should not warn

void foo()
{
    byte[128] small;
    small[0] = 1;

    int x = 42;
    x++;
}

// global variables should not warn regardless of size
__gshared byte[4096] globalBig;
