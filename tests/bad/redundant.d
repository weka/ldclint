// RUN: env ldc2 -wi -c %s -o- --plugin=libldclint.so 2>&1 | FileCheck %s

int foo(int p1)
{
    bool ret;

    // CHECK-DAG: redundant.d(8): Warning: Redundant expression `p1 == p1`
    ret |= p1 == p1;
    // CHECK-DAG: redundant.d(10): Warning: Redundant expression `p1 != p1`
    ret |= p1 != p1;
    // CHECK-DAG: redundant.d(12): Warning: Redundant expression `p1 > p1`
    ret |= p1 > p1;
    // CHECK-DAG: redundant.d(14): Warning: Redundant expression `p1 < p1`
    ret |= p1 < p1;
    // CHECK-DAG: redundant.d(16): Warning: Redundant expression `p1 <= p1`
    ret |= p1 <= p1;
    // CHECK-DAG: redundant.d(18): Warning: Redundant expression `p1 >= p1`
    ret |= p1 >= p1;
    // CHECK-DAG: redundant.d(20): Warning: Redundant expression `p1 is p1`
    ret |= p1 is p1;
    // CHECK-DAG: redundant.d(22): Warning: Redundant expression `p1 !is p1`
    ret |= p1 !is p1;
    // CHECK-DAG: redundant.d(24): Warning: Redundant expression `p1 && p1`
    ret |= p1 && p1;
    // CHECK-DAG: redundant.d(26): Warning: Redundant expression `p1 || p1`
    ret |= p1 || p1;

    int ret2;
    // CHECK-DAG: redundant.d(30): Warning: Redundant expression `p1 - p1`
    ret2 += p1 - p1;
    // CHECK-DAG: redundant.d(32): Warning: Redundant expression `p1 ^ p1`
    ret2 += p1 ^ p1;

    return cast(int)ret + ret2;
}

// CHECK-DAG: redundant.d(38): Warning: Empty `if` body with no `else`
void emptyIf(bool c) { if (c) {} }
// CHECK-DAG: redundant.d(40): Warning: Empty `else` body
void emptyElse(bool c) { if (c) { return; } else {} }
// CHECK-DAG: redundant.d(42): Warning: Empty `if` body with non-empty `else`
void emptyIfWithElse(bool c) { if (c) {} else { return; } }
