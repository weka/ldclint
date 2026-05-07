// RUN: env LDCLINT_FLAGS="-Wno-all -Wunused-imports" ldc2 -wi -c %s -o- --plugin=libldclint.so 2>&1 | FileCheck --implicit-check-not=Warning %s

// CHECK-DAG: unused_imports.d(4): Warning: Imported module `core.stdc.stdio` appears to be unused
import core.stdc.stdio;

// used — should not warn
import core.stdc.stdlib;
void useStdlib() { exit(0); }

// CHECK-DAG: unused_imports.d(11): Warning: Imported module `core.stdc.string` appears to be unused
import core.stdc.string : strlen;

// aliased import that is never referenced — should still warn
// CHECK-DAG: unused_imports.d(15): Warning: Imported module `core.stdc.errno` appears to be unused
import err = core.stdc.errno;
