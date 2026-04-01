// RUN: env LDCLINT_FLAGS="-Wno-all -Wimport-visibility" ldc2 -wi -c %s -o- --plugin=libldclint.so 2>&1 | FileCheck --implicit-check-not=Warning %s

// CHECK-DAG: public_import.d(5): Warning: Import of `core` is public via `public:` block
public:
    import core.stdc.stdio;
