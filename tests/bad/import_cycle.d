// RUN: printf 'module import_cycle_dep;\nimport import_cycle;\n' > %t.d \
// RUN:   && env LDCLINT_FLAGS="-Wno-all -Wimport-cycle=dot-file=%t.dot" ldc2 -wi -c %s %t.d -o- --plugin=libldclint.so 2>&1 \
// RUN:   | FileCheck %s
// RUN: FileCheck --check-prefix=DOT %s < %t.dot
module import_cycle;
import import_cycle_dep;
// CHECK: import_cycle.d(6): Warning: module `import_cycle` imports itself
// CHECK: import_cycle.d(6): `import_cycle` imports `import_cycle_dep`
// CHECK: `import_cycle_dep` imports `import_cycle`
// DOT: "import_cycle" -> "import_cycle_dep"
// DOT: "import_cycle_dep" -> "import_cycle"
