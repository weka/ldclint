# AI Code Agent Guide

This file provides guidance to AI code agents when working with code in this
repository.

## Project Overview

ldclint is an LDC compiler plugin that extends the LDC D compiler with lint
checks on the AST. It produces `libldclint.so`, loaded by LDC via
`--plugin=libldclint.so`. Checks are configured at runtime via the
`LDCLINT_FLAGS` environment variable.

## Build & Test Commands

```bash
make                    # Build libldclint.so (release)
make DEBUG=1            # Build with debug symbols (-g -O0 -debug)
make test               # Build + run all lit tests
make clean              # Remove build artifacts
```

To run a single test:
```bash
make build venv && builddir/.venv/bin/lit -v tests/good/overflow.d
# or
make build venv && builddir/.venv/bin/lit -v tests/bad/overflow.d
```

## Architecture

### Plugin Lifecycle

1. When ldclint is added as plugin to the compiler invocation, it calls
   `ldclint_initialize()` at lload time to setup the plugin environment.
  - Parses `LDCLINT_FLAGS` env var into `Options` (e.g. `-Wall`, `-Wno-all`,
    `-Wredundant-final`).
2. LDC calls the exported `runSemanticAnalysis(Module)` per module
  - Each enabled check is instantiated via `ClassInfo.create()` and run on the
    module.

### Check Registration

Checks self-register via linker sections — no central registry to update:
- Define `enum Metadata` with group, name, and flags
- Extend `GenericCheck!Metadata`
- `mixin RegisterCheck!Metadata` places a `CheckInfo` in the `"ldclint_checks"`
  linker section
- `allChecks()` reads back all entries from that section at runtime

Check full name = `"group-name"` (e.g. `"redundant-final"`). Flags:
`-Wredundant-final` (enable), `-Wno-redundant-final` (disable), `-Wredundant`
(enable whole group).

### DMD AST Integration

- DMD visitor classes are `extern(C++)`. `VisitorProxy` in `dmd/visitor.d`
  auto-generates overrides via `__traits(getOverloads)` to bridge into D-side
  `Visitor` methods
- All DMD AST nodes are wrapped in `Querier!T` which provides `isValid()`,
  `isResolved()`, type helpers, and `alias astNode this` for transparent access
  to the underlying node
- `AbstractCheck` (in `checks/package.d`) skips invalid/generated nodes by
  default. Checks override specific `visit(Querier!(DMD.NodeType))` methods
- Report warnings/errors via `warning(loc, fmt, args...)` and `error(loc, fmt,
  args...)` from `utils/report.d`, which delegate to DMD's built-in diagnostics

### Key Source Files

| File | Role |
|---|---|
| `source/ldclint/plugin.d` | Entry point, check iteration |
| `source/ldclint/checks/package.d` | `AbstractCheck`, `GenericCheck`, `RegisterCheck`, `Metadata` |
| `source/ldclint/utils/visitor.d` | Full AST visitor with 200+ node type handlers |
| `source/ldclint/utils/querier.d` | `Querier!T` wrapper, `Resolved!T`, semantic helpers |
| `source/ldclint/dmd/visitor.d` | `VisitorProxy` — C++ to D visitor bridge |
| `source/ldclint/options.d` | Flag parsing and check enable/disable logic |

## Adding a New Check

1. Create `source/ldclint/checks/<group>_<name>.d`
2. Define module-level `enum Metadata` and a `final class Check :
   GenericCheck!Metadata` with `mixin RegisterCheck!Metadata`
3. Override `visit(Querier!(DMD.<NodeType>))` methods; always call
   `super.visit(...)` to continue traversal
4. Add both `tests/good/<test>.d` (with `-w`, must produce zero warnings) and
   `tests/bad/<test>.d` (with `-wi` + FileCheck assertions)

## Test Format

**Good test** (no warnings expected):
```d
// RUN: env LDCLINT_FLAGS="-Wno-all -Wcheck-name" ldc2 -w -c %s -o- --plugin=libldclint.so
```

**Bad test** (specific warnings expected):
```d
// RUN: env LDCLINT_FLAGS="-Wno-all -Wcheck-name" ldc2 -wi -c %s -o- --plugin=libldclint.so 2>&1 | FileCheck %s
// CHECK-DAG: file.d(LINE): Warning: Expected warning text
```
