// RUN: env LDCLINT_FLAGS="-Wno-all -Wstyle-confusing-precedence" ldc2 -wi -c %s -o- --plugin=libldclint.so 2>&1 | FileCheck %s

// CHECK: Warning: Use parentheses to clarify `&&` and `||` precedence
bool testPrecedence(bool a, bool b, bool c)
{
    return a && b || c;
}
