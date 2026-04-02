// RUN: env LDCLINT_FLAGS="-Wno-all -Wforbid-missing-return" ldc2 -wi -c %s -o- --plugin=libldclint.so 2>&1 | FileCheck %s

// CHECK: Warning: Function declared `auto` inferred as `void`; add an explicit `void` return type, or add the missing `return`.
auto doStuff()
{
    // missing return
}
