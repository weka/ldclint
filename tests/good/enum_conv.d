// RUN: env LDCLINT_FLAGS="-Wno-all -Wenum-conv" ldc2 -w -c %s -o- --plugin=libldclint.so

enum A { a1, a2 }
enum B { b1, b2 }

// same enum type is fine
auto foo(bool cond, A a1, A a2) { return cond ? a1 : a2; }

// explicit cast removes enum type — no warning
auto bar(bool cond, A a, B b) { return cond ? cast(int) a : cast(int) b; }

// non-enum types are fine
auto baz(bool cond, int x, int y) { return cond ? x : y; }

// returning same enum type is fine
A ret_same(A a) { return a; }

// auto return infers enum type — no conversion
auto ret_auto(A a) { return a; }

// explicit cast via local variable — no warning
int ret_cast(A a) { int x = cast(int) a; return x; }

auto lazyFunc(bool cond, lazy A a) { if (cond) return a; else return A.a1; }

int useLazyFunc() {
    lazyFunc(true, A.a2);

    return 0;
}

int useInnerFunc() {
    static auto innerFunc(bool cond, A a) { if (cond) return a; else return A.a1; }
    innerFunc(true, A.a2);

    return 0;
}

int useInnerDg(A a) {
    auto innerDg(bool cond) { if (cond) return a; else return A.a1; }
    innerDg(true);

    return 0;
}

int useLambdaFunc() {
    auto lambda = (bool cond, A a) { if (cond) return a; else return A.a1; };
    lambda(true, A.a2);

    return 0;
}
