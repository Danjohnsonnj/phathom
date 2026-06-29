#!/usr/bin/env python3
"""Audit tag consistency from a Phathom library backup export.

Reads a LibraryBackupService JSON export (formatVersion >= 4) and reports tag
drift: frequency, deterministic near-duplicate clusters, and co-occurrence.
Also emits a compact `tag_vocab.json` to hand to an LLM for a semantic
clustering pass (see docs/_handoff/tech-brief.md).

The audit only reads `items[].tags`; it never touches the live SwiftData store.
Outputs default to the gitignored `tag-audit-work/` directory and must not be
committed (they contain personal tag data).

Usage:
    python3 tools/tag_audit.py path/to/export.json
    python3 tools/tag_audit.py export.json --out tag-audit-work --fuzzy 0.86

Large files: install `ijson` (`pip install ijson`) for low-memory streaming;
otherwise the script falls back to loading the whole file with the stdlib.
"""
from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from difflib import SequenceMatcher
from pathlib import Path
from typing import Iterable, Iterator


def iter_item_tags(path: Path) -> Iterator[list[str]]:
    """Yield the tag list for each exported item, streaming when possible."""
    try:
        import ijson  # type: ignore

        with path.open("rb") as fh:
            for item in ijson.items(fh, "items.item"):
                tags = item.get("tags") or []
                yield [str(t) for t in tags]
        return
    except ImportError:
        print(
            "note: `ijson` not installed; loading whole file with stdlib json "
            "(may use a lot of RAM on huge exports). `pip install ijson` to stream.",
            file=sys.stderr,
        )

    with path.open("r", encoding="utf-8") as fh:
        data = json.load(fh)
    for item in data.get("items", []):
        tags = item.get("tags") or []
        yield [str(t) for t in tags]


def singularize(tag: str) -> str:
    """Cheap English singularization for plural/singular cluster grouping."""
    for suffix, repl in (("ies", "y"), ("ses", "s"), ("es", ""), ("s", "")):
        if tag.endswith(suffix) and len(tag) - len(suffix) >= 2:
            return tag[: -len(suffix)] + repl
    return tag


class UnionFind:
    def __init__(self, items: Iterable[str]) -> None:
        self.parent = {it: it for it in items}

    def find(self, x: str) -> str:
        root = x
        while self.parent[root] != root:
            root = self.parent[root]
        while self.parent[x] != root:
            self.parent[x], x = root, self.parent[x]
        return root

    def union(self, a: str, b: str) -> None:
        ra, rb = self.find(a), self.find(b)
        if ra != rb:
            self.parent[ra] = rb

    def groups(self) -> dict[str, list[str]]:
        out: dict[str, list[str]] = {}
        for item in self.parent:
            out.setdefault(self.find(item), []).append(item)
        return out


def build_clusters(
    counts: Counter[str], fuzzy_threshold: float
) -> list[dict[str, object]]:
    """Group near-duplicate tags via singular/plural and tight fuzzy ratio.

    Deliberately HIGH-PRECISION / low-recall: catches morphology and typos
    (recipe/recipes, machine-learning/machine-learnings) only. Conceptual
    grouping (synonyms, broader/narrower) is left to the LLM semantic pass over
    `tag_vocab.json`. Whole-token containment is intentionally NOT used as a
    merge: short standalone tags (`ai`, `development`) are subsets of dozens of
    compounds and cause transitive single-linkage chaining into one giant blob.
    """
    tags = list(counts)
    uf = UnionFind(tags)

    by_singular: dict[str, list[str]] = {}
    for tag in tags:
        by_singular.setdefault(singularize(tag), []).append(tag)
    for group in by_singular.values():
        for other in group[1:]:
            uf.union(group[0], other)

    for i, a in enumerate(tags):
        for b in tags[i + 1 :]:
            if uf.find(a) == uf.find(b):
                continue
            if SequenceMatcher(None, a, b).ratio() >= fuzzy_threshold:
                uf.union(a, b)

    clusters: list[dict[str, object]] = []
    for members in uf.groups().values():
        if len(members) < 2:
            continue
        members.sort(key=lambda t: (-counts[t], t))
        clusters.append(
            {
                "canonical_guess": members[0],
                "total_count": sum(counts[m] for m in members),
                "members": [{"tag": m, "count": counts[m]} for m in members],
            }
        )
    clusters.sort(key=lambda c: (-int(c["total_count"]), str(c["canonical_guess"])))
    return clusters


def cooccurrence(tag_sets: list[set[str]], top: int) -> list[tuple[str, str, int]]:
    pair_counts: Counter[tuple[str, str]] = Counter()
    for tags in tag_sets:
        ordered = sorted(tags)
        for i, a in enumerate(ordered):
            for b in ordered[i + 1 :]:
                pair_counts[(a, b)] += 1
    return [(a, b, n) for (a, b), n in pair_counts.most_common(top)]


def write_outputs(
    out_dir: Path,
    counts: Counter[str],
    total_items: int,
    total_uses: int,
    clusters: list[dict[str, object]],
    pairs: list[tuple[str, str, int]],
) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)

    freq = counts.most_common()
    (out_dir / "frequency.tsv").write_text(
        "tag\tcount\n" + "".join(f"{t}\t{n}\n" for t, n in freq), encoding="utf-8"
    )

    vocab = [{"tag": t, "count": n} for t, n in freq]
    (out_dir / "tag_vocab.json").write_text(
        json.dumps(vocab, indent=2, ensure_ascii=False), encoding="utf-8"
    )

    (out_dir / "cooccurrence.tsv").write_text(
        "tag_a\ttag_b\tcount\n" + "".join(f"{a}\t{b}\t{n}\n" for a, b, n in pairs),
        encoding="utf-8",
    )

    lines = ["# Near-duplicate tag clusters", ""]
    if not clusters:
        lines.append("_No deterministic near-duplicate clusters found._")
    for c in clusters:
        members = ", ".join(f"`{m['tag']}` ({m['count']})" for m in c["members"])  # type: ignore[index]
        lines.append(
            f"- **{c['canonical_guess']}** (cluster total {c['total_count']}): {members}"
        )
    (out_dir / "clusters.md").write_text("\n".join(lines) + "\n", encoding="utf-8")

    singletons = sum(1 for _, n in freq if n == 1)
    clustered_tags = sum(len(c["members"]) for c in clusters)  # type: ignore[arg-type]
    summary = [
        "# Tag audit summary",
        "",
        f"- Items audited (non-archived): {total_items}",
        f"- Total tag uses: {total_uses}",
        f"- Distinct tags: {len(counts)}",
        f"- Singleton tags (used once): {singletons}",
        f"- Near-duplicate clusters: {len(clusters)} (covering {clustered_tags} tags)",
        f"- Avg tags/item: {total_uses / total_items:.2f}" if total_items else "- Avg tags/item: n/a",
        "",
        "## Top 25 tags",
        "",
        *[f"- `{t}` x{n}" for t, n in freq[:25]],
        "",
        "## Largest near-duplicate clusters",
        "",
        *(
            [
                f"- {c['canonical_guess']} ({c['total_count']}): "
                + ", ".join(m["tag"] for m in c["members"])  # type: ignore[index]
                for c in clusters[:15]
            ]
            or ["- none"]
        ),
        "",
        "Next: feed `tag_vocab.json` to the LLM semantic pass (see tech-brief.md) "
        "-> `canonical-map.json`.",
    ]
    (out_dir / "summary.md").write_text("\n".join(summary) + "\n", encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Audit Phathom library tag consistency.")
    parser.add_argument("export", type=Path, help="path to backup export JSON")
    parser.add_argument(
        "--out", type=Path, default=Path("tag-audit-work"), help="output directory"
    )
    parser.add_argument(
        "--fuzzy",
        type=float,
        default=0.86,
        help="difflib similarity threshold for fuzzy clustering (0-1)",
    )
    parser.add_argument(
        "--cooccur-top", type=int, default=50, help="number of top co-occurring pairs"
    )
    args = parser.parse_args(argv)

    if not args.export.exists():
        print(f"error: export not found: {args.export}", file=sys.stderr)
        return 2

    counts: Counter[str] = Counter()
    tag_sets: list[set[str]] = []
    total_items = 0
    total_uses = 0
    for raw_tags in iter_item_tags(args.export):
        total_items += 1
        unique = {t for t in raw_tags if t}
        total_uses += len(unique)
        counts.update(unique)
        tag_sets.append(unique)

    if total_items == 0:
        print("error: no items found in export (wrong file or empty library?)", file=sys.stderr)
        return 1

    clusters = build_clusters(counts, args.fuzzy)
    pairs = cooccurrence(tag_sets, args.cooccur_top)
    write_outputs(args.out, counts, total_items, total_uses, clusters, pairs)

    print(f"Audited {total_items} items, {len(counts)} distinct tags.")
    print(f"Wrote: {args.out}/summary.md, frequency.tsv, clusters.md, cooccurrence.tsv, tag_vocab.json")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
