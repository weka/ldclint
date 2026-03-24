// RUN: env LDCLINT_FLAGS="-Wpublic-import" ldc2 -w -c %s -o- --plugin=libldclint.so

// explicit public import should not warn
public import core.stdc.stdio;

// private import should not warn
import core.stdc.stdlib;
