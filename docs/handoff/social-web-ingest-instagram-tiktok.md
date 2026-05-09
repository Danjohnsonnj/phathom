# Social web ingest: Instagram and TikTok

> **Status:** **Implemented** for the behaviors below (caption, thumbnail, TikTok transcript when CDN subtitles are available, hashtag merge). **Maintenance:** Meta / TikTok HTML or JSON drift may require parser updates. **Not a TODO list** for the core Phase 2 pipeline — treat changes as bugfixes when real URLs regress.

Phathom captures **web** items with [`WebIngestService.scrape`](../../Phathom/Phathom/Services/WebIngestService.swift) (`iPhone Safari` user agent), then [`BackgroundPipeline`](../../Phathom/Phathom/Services/BackgroundPipeline.swift) runs Llama on `rawText` and merges platform hashtags for social hosts.

## Host behavior (validated with live HTML)

| Host | Caption source | Thumbnail | Generic DOM text (script/style stripped) |
|------|----------------|-----------|-------------------------------------------|
| **Instagram** | `og:description` normalized (stats + quote wrapper stripped); fallback `og:title` with `on Instagram:` framing removed | `og:image` | Often useless (~single word) for reels; rely on OG |
| **TikTok** | Rehydration JSON → `itemStruct.desc` plus optional **spoken transcript** from `video.subtitleInfos` (WEBVTT URL) | `video.cover` (etc.) or `link[rel=preload][as=image]` | ~157 chars marketing copy; not the caption or transcript |

## Shared types ([`PhathomCore`](../../Phathom/PhathomCore/Sources/PhathomCore/))

- **`WebScrapeResult`**: `text`, `thumbnailData`, `displayHost`, `pageTitle`, `suggestedListTitle`.
- **`SocialListTitle`**: first line of caption, max 100 characters, trim to last ASCII space.
- **`InstagramSocialCaption`**: `normalizedCaption(ogDescription:ogTitle:)`, `suggestedListTitle(fromNormalizedCaption:)`; optional **reel audio** first-line drop when line looks like `·` / `•` attribution or “Original sound”.
- **`HashtagParser.tagNames`**: lowercase, deduped, order preserved — merged after Llama tags for `instagram` / `tiktok` hosts.
- **`TikTokItemStructResolver`**: parses rehydration script; tries `__DEFAULT_SCOPE__` → `webapp.reflow.video.detail` → `itemInfo` → `itemStruct`, then **`webapp.video-detail`** path, then **structural** search (`desc` + `author` + `video`). Exposes optional **`subtitleInfos`** pick (prefers **English** `LanguageCodeName` when multiple tracks exist).
- **`WebVTTTranscriptParser`**: strips cue timing and returns plain speech text (length-capped for model context).
- **`TikTokAIArticleText`**: builds stable multi-section `rawText` for TikTok (**Author** / **Transcript** / **Post caption**).

## Title and `rawText`

- **User-entered title** always wins.
- Otherwise **`suggestedListTitle`** (caption-derived), else **`pageTitle`** (generic / OG title), capped at 200 characters on [`ContentItem`](../../Phathom/PhathomCore/Sources/PhathomCore/ContentItem.swift).
- **TikTok `rawText`**: assembled via [`TikTokAIArticleText`](../../Phathom/PhathomCore/Sources/PhathomCore/TikTokAIArticleText.swift): optional **`Author: @handle`**, optional **`Transcript:`** (from fetched WEBVTT when `subtitleInfos` is present), then **`Post caption:`** with `itemStruct.desc`. **List title** is still derived from **`desc` only** (`SocialListTitle.fromCaption(payload.description)`), not from the `Author` line.
- **Transcript fetch**: [`WebIngestService`](../../Phathom/Phathom/Services/WebIngestService.swift) fetches the subtitle URL with the same mobile Safari user agent; failures are **soft** (ingest continues with caption-only sections).

## Hashtag merge

After `session.tagsFromDerived(...)`, **`mergePlatformHashtagTags`** appends tags from `#` tokens in `rawText` for web items whose `displayHost` contains **`instagram`** or **`tiktok`**. Llama tags and hashtag tags are still merged by dedupe.

## Failure modes

- **Login wall / bot HTML**: missing `og:description` or TikTok JSON → **`WebIngestError.emptyContent`** or **`TikTokIngestError`** with a localized description.
- **Meta / TikTok markup drift**: JSON path or OG template may change; extend [`TikTokItemStructResolver`](../../Phathom/PhathomCore/Sources/PhathomCore/TikTokItemStructResolver.swift) or Instagram regex cautiously.
- **Truncated OG**: hashtags at end of caption may be cut off server-side.
- **Subtitle URL expiry**: TikTok CDN subtitle URLs may include short-lived tokens; fetch during ingest soon after page load.

## Future fallback: missing transcript tracks (Instagram)

- **TikTok (current)**: when `video.subtitleInfos` includes a usable `Url`, spoken-audio text is merged into `rawText` under **`Transcript:`** for summarization/tagging alongside the post caption.
- **Instagram (current limitation)**: public reel HTML typically exposes **creator caption** via Open Graph (`og:description` / `og:title`) but **not** a separate downloadable transcript track in the same way as TikTok’s WEBVTT. Ingest therefore remains **caption-first** for Instagram.
- **Fallback policy for AI input**: TikTok = transcript + caption when available; Instagram = caption only unless a future pipeline adds speech-to-text.
- **Potential future improvement**: optional **on-device ASR** (extract audio from video, run a local speech model) or a user-approved third-party transcription path — gated by privacy, thermal, file size, and Terms of Service. Treat unofficial “scrape any reel transcript” APIs as **non-default** (stability and compliance risk).

## Tests

[`PhathomCoreTests/SocialWebIngestTests`](../../Phathom/PhathomCore/Tests/PhathomCoreTests/SocialWebIngestTests.swift): `swift test` from the **PhathomCore** package directory.

## Example URLs (manual smoke)

- TikTok short link (reflow JSON): e.g. `https://www.tiktok.com/t/ZTkpwpWbd/`
- Instagram reel: e.g. `https://www.instagram.com/reel/DXmb8zhtsBr/`
