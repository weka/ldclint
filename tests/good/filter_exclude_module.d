// `-Eturtles.*` excludes any module whose FQN starts with `turtles.`,
// so the unused import below should not be flagged.
// RUN: env LDCLINT_FLAGS="-Wno-all -Wunused-imports -Eturtles.*" ldc2 -w -c %s -o- --plugin=libldclint.so

module turtles.shell;

import core.stdc.stdio;
