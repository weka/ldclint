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

struct Pos
{
    float x, y, z;

    static auto staticPosImplicit1(int x, int y, int z)
    {
        float fx = x;
        float fy = float(y);

        return typeof(this)(fx, fy, float(z));
    }

    static auto staticPosImplicit2(int x, int y, int z)
    {
        float fx = x;
        float fy = float(y);

        return Pos(fx, fy, float(z));
    }

    static Pos staticPosExplicit1(int x, int y, int z)
    {
        float fx = x;
        float fy = float(y);

        return typeof(return)(fx, fy, float(z));
    }

    static Pos staticPosExplicit2(int x, int y, int z)
    {
        float fx = x;
        float fy = float(y);

        return Pos(fx, fy, float(z));
    }
}

auto posImplicit(int x, int y, int z)
{
    float fx = x;
    float fy = float(y);

    return Pos(fx, fy, float(z));
}

Pos posExplicit(int x, int y, int z)
{
    float fx = x;
    float fy = float(y);

    return Pos(fx, fy, float(z));
}

private void someFunctionUsedInTemplate() {}

void someTemplate()()
{
    someFunctionUsedInTemplate();
}

void someTemplate2()()
{
    someFunctionUsedInTemplate2();
}

private void someFunctionUsedInTemplate2() {}
