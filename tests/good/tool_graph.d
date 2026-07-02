// RUN: rm -f %t.graph.dot
// RUN: env LDCLINT_FLAGS="-Wno-all -Wtool-graph=path=%t.graph.dot" ldc2 -w -c %s -o- --plugin=libldclint.so
// RUN: FileCheck %s < %t.graph.dot
// CHECK: digraph {
module tests.good.tool_graph;
import std.stdio;
void use() { writeln("x"); }
