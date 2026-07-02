// RUN: rm -f %t.blame.log
// RUN: env LDCLINT_FLAGS="-Wno-all -Wtool-blame=path=%t.blame.log" ldc2 -w -c %s -o- --plugin=libldclint.so
// RUN: FileCheck %s < %t.blame.log

// CHECK: kind,hash,addr,phash,paddr,file,line,name,size

struct S { int a; void f() {} }
enum E { x, y }
void topFn() {}

// A struct row: kind=struct, deterministic hash, addr/paddr wildcarded,
// file empty (same file as module), some line, name S, nonzero size.
// The file column is empty because these symbols live in this test module
// itself; a path is only emitted when a symbol's file differs from its module.
// CHECK-DAG: struct,0x{{[0-9A-F]+}},0x{{[0-9A-F]+}},0x{{[0-9A-F]+}},0x{{[0-9A-F]+}},,{{[0-9]+}},S,{{[0-9]+}}
// CHECK-DAG: variable,0x{{[0-9A-F]+}},0x{{[0-9A-F]+}},0x{{[0-9A-F]+}},0x{{[0-9A-F]+}},,{{[0-9]+}},a,{{[0-9]+}}
// CHECK-DAG: function,0x{{[0-9A-F]+}},0x{{[0-9A-F]+}},0x{{[0-9A-F]+}},0x{{[0-9A-F]+}},,{{[0-9]+}},topFn,{{[0-9]+}}
// CHECK-DAG: enum,0x{{[0-9A-F]+}},0x{{[0-9A-F]+}},0x{{[0-9A-F]+}},0x{{[0-9A-F]+}},,{{[0-9]+}},E,{{[0-9]+}}
// CHECK-DAG: enum member,0x{{[0-9A-F]+}},0x{{[0-9A-F]+}},0x{{[0-9A-F]+}},0x{{[0-9A-F]+}},,{{[0-9]+}},x,{{[0-9]+}}
