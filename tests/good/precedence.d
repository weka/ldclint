// RUN: env LDCLINT_FLAGS="-Wno-all -Wstyle-confusing-precedence" ldc2 -w -c %s -o- --plugin=libldclint.so

// Parenthesized && with || is fine
bool testParenthesized(bool a, bool b, bool c)
{
    return (a && b) || c;
}

// Only || is fine
bool testOnlyOr(bool a, bool b, bool c)
{
    return a || b || c;
}

// Only && is fine
bool testOnlyAnd(bool a, bool b, bool c)
{
    return a && b && c;
}
