// RUN: env LDCLINT_FLAGS="-Wno-all -Wmustuse-throwable" ldc2 -w -c %s -o- --plugin=libldclint.so

class MyException : Exception
{
    this(string msg) { super(msg); }
}

MyException makeException()
{
    return new MyException("test");
}

// using the return value is fine
void foo()
{
    auto e = makeException();
    throw e;
}

// non-throwable return values are fine to discard
int bar() { return 42; }

void baz()
{
    bar();
}
