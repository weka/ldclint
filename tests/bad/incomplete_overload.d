// RUN: env LDCLINT_FLAGS="-Wno-all -Wsuspicious-overload" ldc2 -wi -c %s -o- --plugin=libldclint.so 2>&1 | FileCheck %s

// CHECK-DAG: incomplete_overload.d(4): Warning: `Rabbit` defines `opEquals` without a matching `toHash`; define both for correct hash-based container behavior.
class Rabbit
{
    bool opEquals(const Rabbit other) const
    {
        return true;
    }
}

// CHECK-DAG: incomplete_overload.d(13): Warning: `Kangaroo` defines `toHash` without a matching `opEquals`; define both for correct hash-based container behavior.
class Kangaroo
{
    override size_t toHash() const nothrow @safe
    {
        return 0;
    }
}

// CHECK-DAG: incomplete_overload.d(22): Warning: `Tarantula` defines `opEquals` without a matching `toHash`; define both for correct hash-based container behavior.
struct Tarantula
{
    bool opEquals(const Tarantula other) const
    {
        return true;
    }
}

// CHECK-DAG: incomplete_overload.d(31): Warning: `Puma` defines `toHash` without a matching `opEquals`; define both for correct hash-based container behavior.
struct Puma
{
    size_t toHash() const nothrow @safe
    {
        return 0;
    }
}
