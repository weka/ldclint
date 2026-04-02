// RUN: env LDCLINT_FLAGS="-Wno-all -Wsuspicious-assert" ldc2 -w -c %s -o- --plugin=libldclint.so

void testValidAsserts(bool condition, int x)
{
    // assert(false) and assert(0) are intentional (unreachable markers)
    // These should not warn
    assert(false);
    assert(0);
    assert(0.0L);

    // Runtime condition asserts - should not warn
    assert(condition);
    assert(x > 0);
}
