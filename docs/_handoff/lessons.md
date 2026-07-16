# Lessons — Annotated Markdown Export

Accreted gotchas and verify outcomes. Prune when obsolete.

- **Overlap wraps:** compute highlight wraps in **ascending** `sourceMarkdownOffset` order so inner spans skip when inside outer envelope; apply all insertions against original UTF-16 indices in one descending pass.
- **macOS Detail share:** `DetailOverflowMenu` uses `ShareLink` in-menu for URL; `onShareLink` / `isPresentingLinkShare` are iOS-only.
