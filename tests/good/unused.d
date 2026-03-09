// RUN: env LDCLINT_FLAGS="-Wunused" ldc2 -w -c %s -o- --plugin=libldclint.so

// underscore-prefixed variables are ignored
private int _ignoredVar;

// main is never considered unused
void main() {}

// public functions are not checked
void publicFunc() {}

// enums are skipped
private enum MyEnum { a, b, c }

// used private function
private int helper(int x) { return x + 1; }
int caller() { return helper(42); }
