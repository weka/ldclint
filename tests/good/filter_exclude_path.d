// Path patterns start with `/` or `./`. `-E/*` excludes everything reached
// via an absolute path — which covers any test source under our tree.
// RUN: env LDCLINT_FLAGS="-Wno-all -Wunused-imports -E/*" ldc2 -w -c %s -o- --plugin=libldclint.so

module turtles.shell;

import core.stdc.stdio;
