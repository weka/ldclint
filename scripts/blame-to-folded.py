#!/usr/bin/env python3
"""
Convert a `tool-blame` CSV into Brendan Gregg's "folded" stack format,
suitable for piping into flamegraph.pl.

Schema (one row per unique AST node — the check side guarantees no
duplicate addresses):

    kind,hash,addr,phash,paddr,file,line,name,size

- `addr` is the AST node's memory address (hex). `paddr` is the parent
  node's address; for root modules it's `0x0`.
- `hash` is a rolling hash over the symbol's (name, kind, size,
  parent-hash) tuple — same logical symbol in the same logical position
  hashes identically, even across distinct AST allocations.
- `name` is the *local* name only; `file` is omitted when it would just
  repeat the enclosing module's source file. The script reconstructs the
  fully-qualified name and file:line by walking back through `paddr` to
  the containing module.

Aggregation rules (the same three the user articulated; the check side
already enforces rule 1 by visiting each AST node once):

  1. Same address chain + same symbol full name → DEDUP.
  2. Different address chain + same symbol full name → SUM. Two
     distinct AST allocations of the same source-level symbol produce
     identical labels at every level and therefore the same folded
     line; their `size` values add.
  3. Different address chain + different full name → SEPARATE frame.

Usage:
    blame-to-folded.py blame.log | flamegraph.pl > blame.svg

flamegraph.pl pairing tip:

    blame-to-folded.py blame.log \\
      | flamegraph.pl --countname=bytes --colors=mem > blame.svg
"""

import argparse
import csv
import sys
from collections import Counter


def clean(s):
    """Strip characters that break flamegraph.pl's one-line format or
    collide with the brackets we use for embedded metadata."""
    if not s:
        return ""
    return (
        s.replace("\r\n", " ")
         .replace("\n", " ")
         .replace("\r", " ")
         .replace("\t", " ")
         .replace(";", "?")
         .replace("[", "(")
         .replace("]", ")")
    )


def main():
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "input",
        nargs="?",
        type=argparse.FileType("r"),
        default=sys.stdin,
        help="tool-blame CSV (default: stdin)",
    )
    args = parser.parse_args()

    # `restval=""` makes rows shorter than the header return ""
    # for the missing columns instead of `None` — downstream string
    # operations all assume strings.
    reader = csv.DictReader(args.input, restval="")
    if reader.fieldnames is None or "addr" not in reader.fieldnames \
            or "paddr" not in reader.fieldnames:
        sys.exit("error: input does not look like a tool-blame CSV "
                 "(expected at least 'addr' and 'paddr' columns)")

    # Index by `addr`. The check writes one row per AST node, so the
    # `if already in` guard is belt-and-suspenders against accidental
    # duplicate rows from a concurrent write.
    rows_by_addr = {}
    order = []
    for row in reader:
        addr = row.get("addr", "")
        if not addr or addr == "0x0":
            continue
        if addr in rows_by_addr:
            continue
        rows_by_addr[addr] = row
        order.append(row)

    def walk_chain(row):
        """Walk parents from leaf to root via `paddr`. Returns the chain
        ordered root → leaf. The `phash` column is intentionally *not*
        used as a lookup key: for `Module` rows the check stores a
        derived parent-hash that doesn't equal the parent module's own
        rolling `hash`, so address-based matching is the canonical link.
        Stops at the root (`paddr == 0x0`), at orphaned references that
        aren't in this CSV, and on any cycle (defensive)."""
        chain = [row]
        seen = {row.get("addr", "")}
        cur = row
        while True:
            paddr = (cur.get("paddr") or "").strip()
            if not paddr or paddr == "0x0" or paddr in seen:
                break
            parent = rows_by_addr.get(paddr)
            if parent is None:
                break
            chain.append(parent)
            seen.add(paddr)
            cur = parent
        chain.reverse()
        return chain

    def label_for(chain, idx):
        """Build a flamegraph frame label for `chain[idx]`.

        The label is `kind:name [fully.qualified.name @ file:line]`:

        - `kind:name` is what shows on narrow frames.
        - The bracketed metadata block is the reconstructed FQN and the
          inherited file:line — both inferred by walking the prefix of
          the chain up to this point.
        - File is propagated down from the closest ancestor that carries
          one (the row's `file` is empty when it matches the enclosing
          module's `srcfile`).
        """
        row = chain[idx]
        kind = clean(row.get("kind", "") or "node")
        name = clean(row.get("name", "") or "<anon>")

        # Reconstruct full qualified name by joining names along the
        # prefix of the chain (root → this position). Skip `<anon>`
        # placeholders so the FQN reads cleanly.
        parts = []
        for c in chain[: idx + 1]:
            n = clean(c.get("name", "") or "")
            if n:
                parts.append(n)
        fqn = ".".join(parts)

        # Walk back up the chain prefix for the nearest non-empty file.
        file_ = ""
        for c in chain[idx::-1]:
            f = clean(c.get("file", "") or "")
            if f:
                file_ = f
                break

        line_ = clean(row.get("line", "") or "")
        if file_ and line_ and line_ != "0":
            loc = f"{file_}:{line_}"
        else:
            loc = file_

        short = f"{kind}:{name}"
        extras = [x for x in (fqn, loc) if x]
        if not extras:
            return short
        return f"{short} [{' @ '.join(extras)}]"

    # Stack key (joined labels root → leaf)  →  total bytes.
    # The check guarantees one row per AST address, so each `order`
    # entry contributes once. Two distinct addresses with identical
    # ancestry produce identical label chains and therefore land in
    # the same Counter bucket — their `size` values add.
    bytes_by_stack = Counter()

    for row in order:
        chain = walk_chain(row)
        if not chain:
            continue

        labels = [label_for(chain, i) for i in range(len(chain))]
        key = ";".join(labels).replace("\n", " ").replace("\r", " ").strip()
        if not key:
            continue

        try:
            size = int(row.get("size") or "0")
        except (ValueError, TypeError):
            continue
        if size <= 0:
            continue

        bytes_by_stack[key] += size

    # Sorted output groups identical prefixes together — what
    # flamegraph.pl's `flow()` expects for clean merging.
    for key in sorted(bytes_by_stack):
        print(f"{key} {bytes_by_stack[key]}")


if __name__ == "__main__":
    main()
