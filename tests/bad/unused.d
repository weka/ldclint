// RUN: env LDCLINT_FLAGS="-Wno-all -Wunused-private" ldc2 -wi -c %s -o- --plugin=libldclint.so 2>&1 | FileCheck --implicit-check-not=Warning %s

// CHECK-DAG: unused.d(4): Warning: Variable `unusedGlobal` appears to be unused
private __gshared int unusedGlobal;

private __gshared int usedGlobal;
int usedGlobalHelper() { return usedGlobal; }

// CHECK-DAG: unused.d(10): Warning: Function `unusedHelper` appears to be unused
private int unusedHelper(int x) { return x; }

int usedPublic()
{
    // CHECK-DAG: unused.d(15): Warning: Variable `localUnused` appears to be unused
    auto localUnused = 42;

    auto localUsed = 10;
    return localUsed;
}
