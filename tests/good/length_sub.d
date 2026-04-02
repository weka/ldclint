// RUN: env LDCLINT_FLAGS="-Wno-all -Wsuspicious-length-subtraction" ldc2 -w -c %s -o- --plugin=libldclint.so

// Addition to length is fine
void testLengthAdd(int[] a, size_t i)
{
    if (i < a.length + 1) {}
}

// Subtraction of two variables is fine
void testVarSubtraction(size_t a, size_t b)
{
    auto c = a - b;
}
