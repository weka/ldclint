// RUN: env LDCLINT_FLAGS="-Wmayoverflow" ldc2 -w -c %s -o- --plugin=libldclint.so

ulong mul(uint lhs, uint rhs)
{
    return cast(ulong)lhs * rhs;
}

ulong mul(ushort val) { return val * 1; }
ulong mul(uint   val) { return val * 0; }
long  mul(int    val) { return val * -1; }
real  mul(float  val) { return val * 1.0f; }
real  mul(double val) { return val * 0.1; }

// negating signed integers is fine
int foo(int a)
{
    return -a;
}

// negating unsigned literals is fine (common pattern)
uint bar()
{
    return -1u;
}

// explicit cast is fine
uint baz(uint a)
{
    return cast(uint)-cast(int)a;
}

// var & -var is fine (bit manipulation: isolate lowest set bit)
uint lowestBit(uint a)
{
    return a & -a;
}
