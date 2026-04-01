// RUN: env LDCLINT_FLAGS="-Wno-all -Wimport-sort" ldc2 -wi -c %s -o- --plugin=libldclint.so 2>&1 | FileCheck --implicit-check-not=Warning %s

// CHECK-DAG: import_sorting.d(5): Warning: Imports are not sorted
import std.stdio;
import std.conv;
