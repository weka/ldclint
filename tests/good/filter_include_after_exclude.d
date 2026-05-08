// `-E*` clears the field, then `-Iabc.xyz` whitelists exactly that name.
// This module is `turtles.shell`, so it remains excluded.
// RUN: env LDCLINT_FLAGS="-Wno-all -Wunused-imports -E* -Iabc.xyz" ldc2 -w -c %s -o- --plugin=libldclint.so

module turtles.shell;

import core.stdc.stdio;
