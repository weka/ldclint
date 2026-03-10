// RUN: env LDCLINT_FLAGS="-Wunused" ldc2 -w -unittest -c %s -o- --plugin=libldclint.so

private string someFunctionForUnittests()
{
    return "Hello, world!";
}

unittest
{
    assert(someFunctionForUnittests() == "Hello, world!");
}
