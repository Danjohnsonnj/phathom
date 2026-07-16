# Phases — Annotated Markdown Export

## Phase 1 — Design

- **Status:** COMPLETE (grill 2026-07-08).
- **Output:** Locked format spec in tech-brief.md.

## Phase 2 — Build

### Increment 1a — Exporter + tests

- Implement `AnnotatedMarkdownExporter` + `HighlightExportInput`.
- Tests: zero highlights, highlight±note, segments, envelope, footnote numbering, overlap, filename slug.
- **Verify:** `cd Phathom/PhathomCore && swift test --filter AnnotatedMarkdownExporterTests`

### Increment 1b — Detail UI + share

- `DetailOverflowMenu` (Share link + Export markdown).
- iOS: `ShareActivityViewController` (separate sheet state for URL vs file).
- macOS: `fileExporter` + `MarkdownExportDocument`.
- **Verify:** `bash scripts/build-phathom.sh sim` + `bash scripts/build-phathom.sh macos`

## Phase 3 — UAT + ship

1. Web article, no highlights → header + body only.
2. Highlight, no note → `==quoted==`.
3. Highlight + note → `==quoted==[^1]` + footnote.
4. Cross-format highlight → per-segment `==`.
5. Share link → URL only.
6. Note/photo Detail → no Export item.
7. macOS smoke.
8. Filename slug readable.

- Update `docs/agents/product-state.md` on pass.
- Commit when user asks.
