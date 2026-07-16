# Tech brief — Annotated Markdown Export

## Architecture

| Layer | Path | Role |
| ----- | ---- | ---- |
| Exporter | `Phathom/PhathomCore/Sources/PhathomCoreMarkdown/AnnotatedMarkdownExporter.swift` | Pure transform: markdown + highlight inputs → export string + filename |
| Tests | `Phathom/PhathomCore/Tests/PhathomCoreTests/AnnotatedMarkdownExporterTests.swift` | Format contract tests |
| UI | `Phathom/Phathom/Views/Shared/DetailBackBarButton.swift` | `DetailOverflowMenu` — Share link + Export markdown |
| Wiring | `Phathom/Phathom/Views/Detail/DetailView.swift` | Mapper `Highlight` → `HighlightExportInput`, share/export actions |

Anchor data reuses existing `Highlight.sourceMarkdownOffset`, `sourceMarkdownLength`, `sourceMarkdownSegmentsJSON` (same JSON shape as `HighlightMarkdownAnchor.Segment`).

## Locked format spec

**Eligibility:** `item.kind == .web` and non-empty `sourceMarkdown`.

**Header** (before body):

```markdown
# {displayTitle}

**Source:** {originalURL or —}
**Exported:** {YYYY-MM-DD}
**Highlights:** {n} ({m} with notes)
```

`en_US_POSIX` date. Nil URL → `**Source:** —`.

**Body:** `sourceMarkdown` with `\r\n` → `\n`.

**Highlights** (apply reverse offset order):

| Case | Markup |
| ---- | ------ |
| Non-empty segments JSON | `==` per `{start,end}` segment |
| No segments / `[]` / decode failure | single `==` on envelope |
| `userNote` | `[^k]` after last closing `==` (or envelope end if wrap skipped) |
| No note | no footnote ref |

**Footnotes** (after body): `[^k]: {userNote}` only; numbers in forward offset order among highlights-with-notes. Multiline notes: indented continuation lines.

**Overlaps:** skip `==` when span ⊆ already-wrapped region; still emit footnote. Partial overlaps: accept nested/adjacent `==` for v1.

**Filename:** `{title-slug}.md` (~80 char kebab from `displayTitle`).

## Verify

- 2a: `cd Phathom/PhathomCore && swift test --filter AnnotatedMarkdownExporterTests`
- 2b: `bash scripts/build-phathom.sh sim` + `bash scripts/build-phathom.sh macos`
