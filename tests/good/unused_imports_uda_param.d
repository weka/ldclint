// `core.attribute.mustuse` is referenced only through a parameter UDA.
// That stores the UDA on `Parameter.userAttribDecl`, a side channel the
// default visitor doesn't traverse — so the import would be falsely
// flagged unless the unused-imports check walks parameter UDAs explicitly.
// RUN: env LDCLINT_FLAGS="-Wno-all -Wunused-imports" ldc2 -w -c %s -o- --plugin=libldclint.so

module unused_imports_uda_param;

import core.attribute : mustuse;

extern(C) int paramUda(@mustuse int x);
