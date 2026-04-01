// RUN: env LDCLINT_FLAGS="-Wno-all -Wimplicit-truncation" ldc2 -w -c %s -o- --plugin=libldclint.so

// casting operand before division is fine
float foo(int a, int b)
{
    return cast(float)a / b;
}

// float division is fine
float bar(float a, float b)
{
    return a / b;
}

// integer division without cast is fine (no promotion)
int baz(int a, int b)
{
    return a / b;
}
