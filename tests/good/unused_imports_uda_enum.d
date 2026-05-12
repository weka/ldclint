// `core.attribute.gnuAbiTag` is referenced only through an enum-member UDA,
// stored on `EnumMember.userAttribDecl` (a side channel the default visitor
// doesn't traverse).
// RUN: env LDCLINT_FLAGS="-Wno-all -Wunused-imports" ldc2 -w -c %s -o- --plugin=libldclint.so

module unused_imports_uda_enum;

import core.attribute : gnuAbiTag;

enum E
{
    @gnuAbiTag("v1") foo,
    bar,
}
