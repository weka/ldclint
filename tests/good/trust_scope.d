// RUN: env LDCLINT_FLAGS="-Wno-all -Wforbid-trusted-block" ldc2 -w -c %s -o- --plugin=libldclint.so

// @trusted on individual function is fine
@trusted void individualFunc() {}

// @trusted as member function attribute is fine
void memberAttrFunc() @trusted {}

// @safe scope is fine
@safe {
    void safeFunc1() {}
    void safeFunc2() {}
}
