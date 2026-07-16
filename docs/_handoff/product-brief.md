# Product brief — Annotated Markdown Export

## Problem

Users highlight articles and add notes in Phathom Detail, but can only share the **original URL**. Colleagues cannot see annotations; users cannot easily harvest quotes + commentary into their own writing.

## Use cases (v1)

1. **Share with colleagues** — annotated article markdown with source attribution.
2. **Draft stockpile** — export many articles as `.md` files for later synthesis.

## Solution

Detail `…` menu → **Export markdown**: standard header + `sourceMarkdown` body with `==highlight==` inline and `[^n]` footnotes (note text only) when a highlight has a `userNote`.

## In scope v1

- Web items with non-empty `sourceMarkdown`.
- Export even when zero highlights (header + pristine body).
- iOS share sheet + macOS file exporter.

## Out of scope v1

- Note/media export, clipboard copy, batch/multi-item export, re-import, format toggles, Phathom branding line.
