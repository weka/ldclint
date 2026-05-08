// `-E*` clears, then `-Iturtles.*` whitelists this module — so the
// unused-imports check still fires.
// RUN: env LDCLINT_FLAGS="-Wno-all -Wunused-imports -E* -Iturtles.*" ldc2 -wi -c %s -o- --plugin=libldclint.so 2>&1 | FileCheck --implicit-check-not=Warning %s

module turtles.shell;

// CHECK-DAG: filter_include_after_exclude.d(8): Warning: Imported module `core.stdc.stdio` appears to be unused
import core.stdc.stdio;
