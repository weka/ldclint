// RUN: env LDCLINT_FLAGS="-Wno-all -Wmustuse" ldc2 -wi -c %s -o- --plugin=libldclint.so 2>&1 | FileCheck --implicit-check-not=Warning %s

class MyException : Exception
{
    this(string msg) { super(msg); }
}

MyException makeException()
{
    return new MyException("test");
}

void foo()
{
    // CHECK-DAG: mustuse.d(16): Warning: Return value of type {{.*}} is discarded
    makeException();
}
