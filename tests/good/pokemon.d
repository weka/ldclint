// RUN: env LDCLINT_FLAGS="-Wno-all -Wsuspicious-generic-catch" ldc2 -w -c %s -o- --plugin=libldclint.so

// Catching Exception is fine
void testCatchException()
{
    try { }
    catch (Exception e) { }
}
