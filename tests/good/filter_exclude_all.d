// `-E*` excludes every module from analysis, so no warnings should fire
// even though the unused-imports check would otherwise flag this file.
// RUN: env LDCLINT_FLAGS="-Wno-all -Wunused-imports -E*" ldc2 -w -c %s -o- --plugin=libldclint.so

module turtles.shell;

import core.stdc.stdio;
