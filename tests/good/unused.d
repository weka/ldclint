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

struct Foo2
{
    int[] arr;
    int[string] assoc;

    void addItem(int item)
    { arr ~= item; }

    void addItems(int[] items)
    {
        foreach(item; items)
            arr ~= item;
    }

    void addStaticForeachItems(int[] items)
    {
        import std.meta : AliasSeq;
        enum DEFAULT_ITEM_IDXS = AliasSeq!(0, 2, 4);

        foreach(i; DEFAULT_ITEM_IDXS)
            arr[i] = items[i];
    }

    void changeItem(size_t index, int item)
    { arr[index] = item; }

    int getItem(size_t index)
    { return arr[index]; }

    void addAssoc(string key, int value)
    { assoc[key] = value; }
}
