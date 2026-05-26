#!/usr/bin/env python3
"""Parse Phathom Swift Testing sources → -only-testing identifiers (suffix or full paths)."""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import defaultdict
from pathlib import Path


TARGET = "PhathomTests"


def last_suite_label_before(text: str, pos: int) -> str | None:
    seg = text[:pos]
    last: str | None = None
    for sm in re.finditer(r'@Suite\s*\(\s*"([^"]*)"', seg):
        last = sm.group(1)
    return last


def enclosing_struct_before(text: str, pos: int) -> tuple[str | None, int]:
    prefix = text[:pos]
    best: tuple[str | None, int] = (None, -1)
    for mm in re.finditer(r'\bstruct\s+(\w+Tests)\b', prefix):
        name = mm.group(1)
        start_ch = mm.start()
        best = (name, start_ch)
    return best


def parse_swift_file(path: Path, repo_root: Path) -> list[dict]:
    text = path.read_text(encoding="utf-8")
    out: list[dict] = []
    rel_file = path.relative_to(repo_root)

    for tm in re.finditer(r"@Test\b", text):
        i = tm.start()
        window = text[i : i + 8192]
        fm = re.search(r"\bfunc\s+(\w+)\s*\(", window)
        if not fm:
            continue
        fname = fm.group(1)
        sn, ss = enclosing_struct_before(text, i)
        if not sn:
            continue
        suite_label = last_suite_label_before(text, ss)
        suf = f"{sn}/{fname}()"
        out.append(
            {
                "file": str(rel_file),
                "struct": sn,
                "suite_label": suite_label,
                "func": fname,
                "suffix": suf,
                "full": f"{TARGET}/{suf}",
            }
        )
    return out


def discover_tests(test_root: Path, repo_root: Path) -> list[dict]:
    seen: dict[str, dict] = {}
    for path in sorted(test_root.glob("*.swift")):
        for row in parse_swift_file(path, repo_root):
            seen[row["full"]] = row
    return sorted(seen.values(), key=lambda r: (r["struct"], r["func"]))


def compact_only_testing(rows: list[dict], matched: list[dict]) -> list[str]:
    totals: dict[str, list[dict]] = defaultdict(list)
    for r in rows:
        totals[r["struct"]].append(r)
    by_hit: dict[str, list[dict]] = defaultdict(list)
    for r in matched:
        by_hit[r["struct"]].append(r)
    out: list[str] = []
    for struct_name, mh in sorted(by_hit.items()):
        all_for = totals[struct_name]
        hit_set = {x["full"] for x in mh}
        if len(hit_set) == len(all_for):
            out.append(f"{TARGET}/{struct_name}")
        else:
            out.extend(sorted(hit_set))
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    repo_root_default = Path(__file__).resolve().parent.parent
    ap.add_argument("--root", type=Path, metavar="TESTS_DIR", default=repo_root_default / "Phathom" / "PhathomTests")
    ap.add_argument("--repo-root", type=Path, default=repo_root_default)
    mx = ap.add_mutually_exclusive_group()
    mx.add_argument("--json", action="store_true")
    mx.add_argument("--grep", metavar="REGEX")
    mx.add_argument("--list", dest="human_list", action="store_true")
    mx.add_argument("--resolve", metavar="NAME", help="print single -only-testing id (FUNC, Struct/func, or full path)")

    ns = ap.parse_args()
    test_root = ns.root.expanduser().resolve()
    repo_root = ns.repo_root.expanduser().resolve()

    try:
        rows = discover_tests(test_root, repo_root)
    except OSError as e:
        print(e, file=sys.stderr)
        sys.exit(2)

    if ns.json:
        for r in rows:
            print(json.dumps(r))
        return

    if ns.resolve is not None:
        raw = ns.resolve.strip()
        if raw.startswith(TARGET + "/"):
            raw = raw[len(TARGET) + 1 :]

        if "/" in raw and raw.endswith("()"):
            cand = [r for r in rows if r["suffix"] == raw]
            if len(cand) == 1:
                print(cand[0]["full"])
                return
            print(f"No test matches suffix {TARGET}/{raw}", file=sys.stderr)
            sys.exit(1)

        base = raw.removesuffix("()")
        by_func = [r for r in rows if r["func"] == base]
        if len(by_func) == 1:
            print(by_func[0]["full"])
            return
        if len(by_func) > 1:
            print(f"ambiguous name '{base}' — matches:", file=sys.stderr)
            for r in sorted(by_func, key=lambda x: x["full"]):
                print(f"  {r['full']}", file=sys.stderr)
            sys.exit(2)

        struct_names = sorted({r["struct"] for r in rows})
        if raw in struct_names:
            print(f"{TARGET}/{raw}")
            return
        if f"{raw}Tests" in struct_names:
            print(f"{TARGET}/{raw}Tests")
            return

        print(f"No test or suite matches '{ns.resolve}'", file=sys.stderr)
        sys.exit(1)

    if ns.grep:
        try:
            cre = re.compile(ns.grep, re.IGNORECASE)
        except re.error as e:
            print(f"invalid regex: {e}", file=sys.stderr)
            sys.exit(2)
        matched = []
        for r in rows:
            hay = f"{r['struct']} {r.get('suite_label') or ''} {r['func']}"
            if cre.search(hay):
                matched.append(r)
        if not matched:
            sys.exit(1)
        for oid in compact_only_testing(rows, matched):
            print(oid)
        return

    if ns.human_list:
        by_struct: dict[str, list[dict]] = defaultdict(list)
        for r in rows:
            by_struct[r["struct"]].append(r)
        for struct in sorted(by_struct):
            first = by_struct[struct][0]
            lab = first.get("suite_label")
            head = struct
            if lab:
                head = f'{struct}  (@Suite "{lab}")'
            print(head)
            for r in by_struct[struct]:
                print(f"  {r['full']}")
            print()
        print(f"{len(rows)} test(s) in {len(by_struct)} suite(s).")
        return

    ap.print_help()


if __name__ == "__main__":
    main()
