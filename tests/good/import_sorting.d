// RUN: env LDCLINT_FLAGS="-Wno-all -Wimport-sort" ldc2 -w -c %s -o- --plugin=libldclint.so

// sorted imports should not warn
import std.conv;
import std.stdio;

// gap between groups resets sorting — each group is independent
import std.string;

import std.algorithm;
