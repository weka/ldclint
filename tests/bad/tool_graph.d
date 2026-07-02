// RUN: rm -f %t.graph.dot
// RUN: env LDCLINT_FLAGS="-Wno-all -Wtool-graph=path=%t.graph.dot,metrics=size" ldc2 -w -c %s -o- --plugin=libldclint.so
// RUN: FileCheck %s < %t.graph.dot

// CHECK-DAG: subgraph "cluster_{{[0-9A-F]+}}" {
// CHECK-DAG: root=1
// a dependency edge to another module's cluster
// CHECK-DAG: -> "{{[0-9A-F]+}}" [lhead="cluster_{{[0-9A-F]+}}"
// functions are collapsed into a counter because they are not in `nodes`
// CHECK-DAG: n_function={{[0-9]+}}

module tests.bad.tool_graph;
import std.stdio;
void a() {}
void b() {}
