# Phase 1 Hand-off: UI Shell + Library/Detail (Stubbed Data)

## Project Snapshot

**Phathom** is a local-only iOS "personal brain" app that captures web links, photos, and notes, then uses on-device AI to summarize, tag, and extract key information. Users review their library and conduct AI-powered research via a RAG chat interface.

- **Platform**: iOS 26+, Swift 5, SwiftUI, SwiftData
- **Target hardware**: iPhone 16 Pro (A17 Pro / Apple Neural Engine)
- **Storage**: Local-only SwiftData — no CloudKit, no sync, no server
- **App name**: Phathom (bundle ID: `com.phathom.Phathom`)
- **Repo root**: project is at repo root; Xcode project is at `Phathom/Phathom.xcodeproj`

Reference docs (read these if you need more context, but this hand-off is self-contained):

- [docs/product-brief.md](../product-brief.md) — product vision
- [docs/technical-brief.md](../technical-brief.md) — technical architecture
- [docs/decisions.md](../decisions.md) — all decisions and rationale
- [docs/assets/main-screen.PNG](../assets/main-screen.PNG) — library screen mockup
- [docs/assets/detail-screen.PNG](../assets/detail-screen.PNG) — detail screen mockup

---

## Agent Guardrails

**Read this section first. These rules are non-negotiable.**

### Source of truth hierarchy

1. **`docs/decisions.md`** — highest authority. If a decision is logged there, it is final.
2. **This hand-off document** — defines scope, schema, file tree, and acceptance criteria.
3. **Mockup PNGs** — visual reference only. Where a mockup conflicts with this document or the decisions log, the **document wins**.

Concrete example: the mockup shows "LinkSavr" and a FAB button. The decision log says the name is "Phathom" and the FAB is removed. **Implement what the documents say, not what the PNG shows.**

### Behavioral rules

- **Build, don't plan.** Your job is to produce working code that passes the acceptance criteria. Do not produce planning documents, QA scripts, architectural write-ups, or ask to "draft an approach" before starting. Read the spec, then implement.
- **Do not invent features.** If something appears in the mockup but is not mentioned in this hand-off document (e.g., a profile avatar, a search history, onboarding screens), it does not exist. Do not build it, stub it, or ask about it.
- **Do not re-litigate decisions.** The decisions log records choices that have already been debated and resolved. Do not propose alternatives to logged decisions (e.g., suggesting CloudKit, FoundationModels, or a different tab structure). If you believe a decision is causing a technical problem during implementation, state the problem factually and ask the user.
- **Schema is frozen** except where **`docs/decisions.md`** explicitly extends it. The models in this document are the contract for the project; the only approved addition to date is **`archivedAt`** on **`ContentItem`** (archive retention). Do not add any **other** properties or change types without escalation.
- **No third-party dependencies.** Phase 1 uses only Apple frameworks (SwiftUI, SwiftData, Foundation). Do not add any Swift packages, CocoaPods, or other external dependencies.
- **Stay in your phase.** Do not build, prototype, or "prepare for" Phase 2 or Phase 3 features. No AI integration stubs, no BGTaskScheduler registration, no Llama.cpp references. **Chat** and **Add New** remain **placeholders** (minimal UX). **Settings** must include **Recently Deleted** (see [Archive & Recently Deleted](#archive--recently-deleted-soft-delete)) and basic about/version rows — **not** model management (Phase 2).
- **Preserve what works.** Do not modify test stubs in `PhathomTests/` or `PhathomUITests/` unless the acceptance criteria require it. Do not change the Xcode project structure (groups, targets, build settings) beyond what is needed to add the specified files.

### Decision framework — handling unknowns

You will encounter situations this spec does not explicitly cover. Use this ordered framework to decide what to do:

**Step 1: Is it a technical blocker?**
The spec says to do X but X doesn't compile, is deprecated, or behaves unexpectedly on the target OS/SDK.
- **Action**: Find the closest equivalent that achieves the same user-visible result. Use the standard Apple-recommended replacement. Do not invent a novel approach. Briefly note what you changed and why in a code comment at the call site.
- Example: if a SwiftUI modifier is deprecated in iOS 26, use its replacement. If `NavigationStack` behaves differently than expected with `@Query`, adjust the view structure to get the same navigation behavior.

**Step 2: Is it an ambiguity gap?**
The spec doesn't say what should happen in a specific scenario (e.g., empty state, edge case layout, what happens when a button is tapped but the action is a stub).
- **Action**: Apply the **minimum viable behavior** principle — implement the simplest reasonable thing a user would expect, then move on. Do not over-design for unspecified scenarios.
- Defaults to apply when the spec is silent:
  - Empty states: show a centered label describing what will appear (e.g., "No items yet").
  - Stub actions: show a brief toast, alert, or print statement — not a crash, not nothing.
  - Layout edge cases: let SwiftUI's default behavior handle it (truncation, scrolling, safe areas).
  - Sort order: `createdAt` descending (newest first) unless the spec says otherwise.

**Step 3: Is it a product decision?**
You've identified something that could reasonably go multiple ways and the choice would change what the user sees or how the app behaves in a non-trivial way.
- **Action**: **Stop and ask the user.** Frame it as: "The spec doesn't cover [situation]. I see two options: [A] or [B]. [A] is simpler / matches the mockup better / is more conventional. Which do you prefer?" Do not block all other work while waiting — continue with unrelated tasks if possible.
- Examples that require asking: whether filter pill selection persists across app launches, whether the "Add New" placeholder should actually create real `ContentItem` records. (**Archive** behavior is **decided** — see [Archive & Recently Deleted](#archive--recently-deleted-soft-delete) and `docs/decisions.md`.)

**Step 4: Is it a structural constraint?**
You need to change something in the guardrails' "must escalate" list (schema, dependencies, tab structure, navigation hierarchy).
- **Action**: **Full stop on that task.** Describe the problem, what you tried, and why the constraint is blocking you. Do not work around it silently. The guardrail exists for cross-phase reasons you may not have context for.

**General principle**: Bias toward **shipping something reasonable and noting it** over **stopping to ask about every detail**. The user can refine a working app faster than they can answer twenty questions about hypothetical edge cases.

### Completion protocol

When you believe the work is done:
1. Verify every acceptance criteria checkbox can be checked.
2. Confirm the app builds without warnings or errors for **iPhone 16 Pro or newer** (simulator or device). Prefer **`bash scripts/build-phathom.sh all`** or `-destination 'platform=iOS Simulator,name=iPhone 16 Pro'`; see [phase-2-pipeline.md](phase-2-pipeline.md) § “Build and simulator destinations”.
3. Confirm SwiftUI Previews render for the library and detail screens.
4. State which acceptance criteria are met and which (if any) are not, with reasons.
5. List any decisions you made under Steps 1-2 of the decision framework (technical workarounds or ambiguity defaults) so the user can review them.

---

## What Exists Right Now

The Xcode project is a **fresh template** with no real implementation:

- `Phathom/Phathom/PhathomApp.swift` — entry point, creates `ModelContainer` for a generic `Item` model
- `Phathom/Phathom/Item.swift` — template model with only a `timestamp: Date` field
- `Phathom/Phathom/ContentView.swift` — template `NavigationSplitView` + `List` of `Item` records
- `Phathom/PhathomTests/`, `Phathom/PhathomUITests/` — empty test stubs

**All of these will be replaced.** `Item.swift` and `ContentView.swift` should be deleted or fully rewritten.

---

## Scope and Deliverables

### Goal

A navigable, visually complete app populated with realistic seed data. **No real AI and no background processing in Phase 1.** (A **share extension** ships in a later target, `PhathomShare` — it was not part of the Phase 1 acceptance bar.) The UI must match the mockups and be backed by the final SwiftData schema so later phases wire in real data without schema migrations.

### Files to Create

```
Phathom/Phathom/
├── Models/
│   ├── ContentItem.swift        # @Model — the core data record
│   ├── Tag.swift                # @Model — tag entity
│   ├── ChatThread.swift         # @Model — placeholder for Phase 3
│   ├── ChatMessage.swift        # @Model — placeholder for Phase 3
│   └── Enums.swift              # ContentKind, ProcessingStatus
├── Helpers/
│   ├── CodableHelpers.swift     # JSON encode/decode for summaryBullets, extracts
│   ├── ThumbnailFallback.swift  # Deterministic color from UUID + content-kind icon
│   └── SeedData.swift           # Populates dev/preview with realistic items
├── Views/
│   ├── MainTabView.swift        # TabView shell (replaces ContentView.swift)
│   ├── Library/
│   │   ├── LibraryTab.swift     # NavigationStack + list + search + filter
│   │   ├── FilterPills.swift    # Horizontal chip selector
│   │   └── ContentCardRow.swift # Single library row with thumbnail, state badge
│   ├── Detail/
│   │   ├── DetailView.swift     # Scroll layout with all sections
│   │   ├── HeroSection.swift    # Full-width image + Visit Site overlay
│   │   ├── TagChipsView.swift   # Horizontally wrapping tag row
│   │   └── ExtractsSection.swift# Label/value pairs
│   ├── Chat/
│   │   └── ChatTab.swift        # Placeholder — "Deep Dive coming in a future update"
│   ├── AddNew/
│   │   └── AddNewTab.swift      # Placeholder — minimal manual entry form
│   └── Settings/
│       ├── SettingsTab.swift        # App version, about, navigation to Recently Deleted
│       └── RecentlyDeletedView.swift # Recover or permanently delete archived items (48h window)
└── PhathomApp.swift             # Updated ModelContainer registration
```

### Files to Delete

- `Phathom/Phathom/Item.swift`
- `Phathom/Phathom/ContentView.swift`

---

## Data Contract — SwiftData Schema

This is the **final schema** for the entire project. Define it completely in Phase 1 even though most AI-populated fields will be nil or stubbed. This avoids SwiftData migration issues in later phases.

### Enums.swift

```swift
import Foundation

enum ContentKind: String, Codable, CaseIterable {
    case web
    case media
    case note
}

enum ProcessingStatus: String, Codable, CaseIterable {
    case pending
    case scraping
    case embedding
    case summarizing
    case tagging
    case completed
    case failed
}
```

### ContentItem.swift

```swift
import Foundation
import SwiftData

@Model
final class ContentItem {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var title: String?
    var originalURL: URL?
    var displayHost: String?
    var contentKind: String
    var rawText: String?
    var thumbnailData: Data?
    var thumbnailColorHex: String?
    var mediaDescription: String?
    var summaryBullets: String?
    var extracts: String?
    var processingStatus: String = ProcessingStatus.pending.rawValue
    var processingDetail: String?
    var lastProcessedChunk: Int = 0
    var failureReason: String?
    var isArchived: Bool = false
    /// Set to `Date()` when the user archives; cleared on restore. Used for the 48-hour retention window (see Archive & Recently Deleted).
    var archivedAt: Date? = nil
    @Relationship(deleteRule: .nullify) var tags: [Tag] = []

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        contentKind: ContentKind = .web,
        originalURL: URL? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.contentKind = contentKind.rawValue
        self.originalURL = originalURL
        self.displayHost = originalURL?.host()
        self.thumbnailColorHex = ContentItem.deterministicColor(from: id)
    }

    static func deterministicColor(from uuid: UUID) -> String {
        let colors = [
            "#5E5CE6", "#BF5AF2", "#FF9F0A", "#30D158",
            "#64D2FF", "#FF375F", "#FFD60A", "#AC8E68"
        ]
        let hashValue = abs(uuid.uuidString.hashValue)
        return colors[hashValue % colors.count]
    }
}
```

**Why `String` instead of enum raw types for `contentKind` and `processingStatus`:** SwiftData does not natively persist custom enums. Store the raw value and use computed properties or the Codable helpers for type-safe access.

### Tag.swift

```swift
import Foundation
import SwiftData

@Model
final class Tag {
    @Attribute(.unique) var name: String
    @Relationship(inverse: \ContentItem.tags) var items: [ContentItem] = []

    init(name: String) {
        self.name = name.lowercased().trimmingCharacters(in: .whitespaces)
    }
}
```

### ChatThread.swift and ChatMessage.swift

```swift
// ChatThread.swift
import Foundation
import SwiftData

@Model
final class ChatThread {
    var id: UUID
    var topic: String
    var createdAt: Date
    @Relationship var messages: [ChatMessage] = []
    @Relationship var sourceTags: [Tag] = []

    init(topic: String, sourceTags: [Tag] = []) {
        self.id = UUID()
        self.topic = topic
        self.createdAt = Date()
        self.sourceTags = sourceTags
    }
}

// ChatMessage.swift
import Foundation
import SwiftData

@Model
final class ChatMessage {
    var role: String
    var text: String
    var timestamp: Date

    init(role: String, text: String) {
        self.role = role
        self.text = text
        self.timestamp = Date()
    }
}
```

---

## Archive & Recently Deleted (soft delete)

**Product behavior (decision: Option B — see [docs/decisions.md](../decisions.md)):** Archiving **removes the item from the Library and all type filters** as if it were deleted from the user's data. The row must not appear in search-on-device lists that mirror the main library (`@Query` must exclude `isArchived == true`). Internally the `ContentItem` remains in SwiftData until **48 hours after `archivedAt`**, after which it is **permanently deleted** by a purge pass.

### Mutations

| Action | `isArchived` | `archivedAt` | Notes |
|--------|--------------|--------------|--------|
| User archives | `true` | `Date()` | Immediately after setting, **pop** the navigation stack if archiving from detail so the user returns to the library. |
| **Undo** (toast, ~5s) | `false` | `nil` | Same session undo; no navigation required if still on library. |
| **Restore** (Recently Deleted) | `false` | `nil` | User returns item to the library. |
| **Delete Permanently** (Recently Deleted) | — | — | `modelContext.delete(item)`. |
| Purge (system) | `true` | `< now − 48h` | Hard-delete matching rows (see below). |

### Library `@Query` predicate

All library lists (including search field filtering **over the main catalog**) must only include **non-archived** items, e.g. `#Predicate<ContentItem> { !$0.isArchived }` combined with existing `contentKind` / text filters.

**Optional UX:** a **swipe action** on a library row ("Archive") performs the same mutation + undo toast — mirrors Mail/Notes and avoids opening detail only to archive.

### Undo toast (immediate recovery)

On archive (from **detail** or **swipe**):

1. Apply the mutation above.
2. Show a **bottom toast / snackbar** (or `safeAreaInset`) with copy such as **"Archived. You can restore it from Recently Deleted within 2 days."** and a prominent **Undo** action.
3. **Undo** expires within **~5 seconds** (match iOS Mail-style expectations). Tapping **Undo** sets `isArchived = false` and `archivedAt = nil`. If the user had been popped from detail, **do not** automatically push detail again unless you keep a local flag — simplest acceptable behavior: Undo restores the item **in the library only** (user can tap the row again).

### Settings → Recently Deleted

`RecentlyDeletedView` is pushed from **Settings** (navigation destination or sheet — pick one pattern and use it consistently).

- **`@Query`**: `FetchDescriptor` with predicate `isArchived == true`, sort by `archivedAt` **descending** (newest archives first).
- **Each row**: thumbnail/title/host (reuse row styling from the library if practical), plus secondary text for **time until permanent deletion**, e.g. **"Permanently deletes in 1 day"**, **"Deletes today"**, derived from `archivedAt!.addingTimeInterval(48 * 3600)` vs `Date()`.
- **Swipe or trailing actions**: **Restore** (un-archive), **Delete Permanently** (confirm with `confirmationDialog` / alert).
- **Toolbar (optional):** **Delete All** — only enabled when the list is non-empty; confirm before deleting every archived item immediately.
- **Empty state:** short explanation — *Nothing in Recently Deleted.*

**Optional:** When `count > 0`, show a **small numeric badge** on the Settings tab or on the "Recently Deleted" row in `SettingsTab` so users know items are pending expulsion.

### Purge expired archives (Phase 1 minimum)

Run a **single efficient fetch** before relying on a "clean" library (and to honor the 48-hour contract without timers):

```swift
// Pseudocode — adjust for your SwiftData `#Predicate` / optional unwrapping rules
let retentionSeconds: TimeInterval = 48 * 60 * 60
let cutoff = Date().addingTimeInterval(-retentionSeconds)
// Fetch items where isArchived == true AND archivedAt != nil AND archivedAt < cutoff
// modelContext.delete(each) then save
```

**When to run:** at least on **`MainTabView.onAppear`** and when the app becomes **active** (`scenePhase == .active` on the root view or app entry). That covers normal use; **Phase 2** duplicates this inside **`BGAppRefreshTask`** so items are purged even if the user does not open the app for days.

**Efficiency:** one fetch + batch delete. No polling. No per-row timers.

### Phase 2 hooks (do not implement in Phase 1)

See [phase-2-pipeline.md](phase-2-pipeline.md): **Spotlight** de-index on archive, re-index on restore when applicable; **background pipeline** must **skip** `isArchived == true` items; **BG refresh** runs the same purge.

---

## Tricky Part: Codable Helpers for JSON Fields

`summaryBullets` and `extracts` are stored as JSON strings. Provide a helper that views use to decode/encode without boilerplate.

### CodableHelpers.swift

```swift
import Foundation

struct Extract: Codable, Identifiable {
    var id: String { label }
    let label: String
    let value: String
}

extension ContentItem {
    var decodedSummaryBullets: [String] {
        guard let data = summaryBullets?.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    func encodeSummaryBullets(_ bullets: [String]) {
        summaryBullets = String(data: (try? JSONEncoder().encode(bullets)) ?? Data(), encoding: .utf8)
    }

    var decodedExtracts: [Extract] {
        guard let data = extracts?.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([Extract].self, from: data)) ?? []
    }

    func encodeExtracts(_ items: [Extract]) {
        extracts = String(data: (try? JSONEncoder().encode(items)) ?? Data(), encoding: .utf8)
    }
}
```

---

## Tricky Part: Thumbnail Fallback View

When `thumbnailData` is nil, the library row and detail hero must render a colored placeholder with an icon. This must look intentional, not broken.

### ThumbnailFallback.swift

```swift
import SwiftUI

struct ThumbnailView: View {
    let thumbnailData: Data?
    let colorHex: String?
    let contentKind: ContentKind
    let size: CGFloat

    var body: some View {
        Group {
            if let data = thumbnailData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color(hex: colorHex ?? "#5E5CE6")
                    Image(systemName: iconName)
                        .font(.system(size: size * 0.35))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.15))
    }

    private var iconName: String {
        switch contentKind {
        case .web: return "globe"
        case .media: return "photo"
        case .note: return "note.text"
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
```

---

## Visual Spec — Library Screen (main-screen.PNG)

Refer to [docs/assets/main-screen.PNG](../assets/main-screen.PNG).

**Layout, top to bottom:**

1. **Navigation bar**: search icon (leading), centered title "Phathom", profile avatar (trailing). Use `.navigationTitle("Phathom")` with `.navigationBarTitleDisplayMode(.inline)` for the nav bar, and a **large-style subtitle** "Recent items" rendered as a `Text` with `.font(.largeTitle)` below the nav bar inside the scroll content.
2. **Filter pills**: horizontal row of chips — "All" (selected/filled), "Web", "Media", "Notes". Not a `Picker`. Custom capsule buttons with filled vs. outlined states. Tapping a pill filters the `@Query` by `contentKind`.
3. **Card list**: each row contains:
   - Left: 70-80pt rounded thumbnail (image or fallback)
   - Right: title (bold, 1 line), domain or description (secondary, 2 lines), timestamp (`"Jul 15, 2026 at 10:45am"` — use `.formatted()` with date+time style)
   - State badge: if `processingStatus != .completed`, show a capsule meta chip (same styling as Detail) bound to granular `ProcessingStatus` via **`ProcessingStatusPresentation`** in [`Phathom/Phathom/Helpers/ProcessingStatusPresentation.swift`](../../Phathom/Phathom/Helpers/ProcessingStatusPresentation.swift): **Queued**, **Fetching source**, **Preparing analysis**, **Generating summary**, **Creating tags**, **Needs attention** (`.failed`). Hide when `.completed`. Updates live as `@Query` / background writes advance `processingStatus`.
4. **Tab bar**: 4 tabs — Library (photo icon, selected), Chat (bubble icon), Add new (plus icon), Settings (gear icon).

**Dark mode**: the mockup uses a dark background. Use the system dark appearance; do not hardcode colors. The card rows should have a slightly elevated surface (`Color(.secondarySystemGroupedBackground)` or a custom Material).

### Tricky Part: Filter Pills

```swift
struct FilterPills: View {
    @Binding var selected: ContentKind?

    private let options: [(label: String, kind: ContentKind?)] = [
        ("All", nil),
        ("Web", .web),
        ("Media", .media),
        ("Notes", .note),
    ]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(options, id: \.label) { option in
                Button {
                    selected = option.kind
                } label: {
                    Text(option.label)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            selected == option.kind
                                ? Color.accentColor
                                : Color(.tertiarySystemFill)
                        )
                        .foregroundStyle(
                            selected == option.kind
                                ? .white
                                : .primary
                        )
                        .clipShape(Capsule())
                }
            }
        }
    }
}
```

---

## Visual Spec — Detail Screen (detail-screen.PNG)

Refer to [docs/assets/detail-screen.PNG](../assets/detail-screen.PNG).

**Layout, top to bottom in a `ScrollView`:**

1. **Navigation bar**: back button "< Recent Items", centered title "Phathom", share button (trailing). Standard `NavigationStack` back behavior.
2. **Hero image**: full-width, ~200pt tall, `contentMode: .fill`, clipped. Overlaid "Visit Site" button (centered, capsule, blue tint). For non-web items or nil thumbnails, use the fallback view at full width.
3. **Domain + Title block**: `displayHost` as a small tinted link label, `title` as `.title.bold()`, summary snippet as `.subheadline` secondary, `createdAt` formatted.
4. **AI Summary section**: section header "AI Summary" (`.headline.bold()`), followed by bullet points. Each bullet is a `Text` with a leading bullet character ("• ") in a `VStack(alignment: .leading)`. If `processingStatus != .completed`, show 3-4 skeleton/redacted placeholder lines.
5. **Tags section**: header "Tags", then a wrapping horizontal flow of capsule chips. Each chip: rounded rect, label in `.caption.weight(.medium)`. Use a `FlowLayout` or a simple `LazyVGrid` with flexible columns.
6. **Extracts section**: header "Extracted Key Figures" (keep the mockup's label), bullet-style label · value pairs.
7. **Action buttons**: horizontal row of rounded-rect buttons — "Read Full Text (AI Parsed)", "Translate", **"Archive"** (see [Archive & Recently Deleted](#archive--recently-deleted-soft-delete): sets `isArchived = true`, `archivedAt = Date()`, pops back to library, shows undo toast). These should look like secondary action buttons (outlined or filled secondary style).
8. **Source Content section**: header "Source Content", collapsed preview of `rawText` (3-4 lines), tappable to expand via `DisclosureGroup` or a "Show more" button.

---

## Seed Data

Create a `SeedData.swift` file with a static function that populates the ModelContext when the store is empty (or via a `#Preview` container). Match the mockup items:

```swift
import SwiftData
import Foundation

struct SeedData {
    @MainActor
    static func populate(_ context: ModelContext) {
        let wwdc = ContentItem(
            createdAt: date("2026-07-15T10:45:00"),
            contentKind: .web,
            originalURL: URL(string: "https://developer.apple.com/wwdc24")!
        )
        wwdc.title = "WWDC24 Keynote"
        wwdc.processingStatus = ProcessingStatus.summarizing.rawValue
        wwdc.processingDetail = "Processing"

        let cityArticle = ContentItem(
            createdAt: date("2026-01-10T09:45:00"),
            contentKind: .web,
            originalURL: URL(string: "https://www.designboom.com/architecture/future-city-concepts")!
        )
        cityArticle.title = "Future City Concepts"
        cityArticle.processingStatus = ProcessingStatus.completed.rawValue
        cityArticle.encodeSummaryBullets([
            "Comprehensive overview of new urban development models.",
            "Focus on vertical farming and integrated renewable energy systems.",
            "Discussion of community spaces and transportation efficiency in high-density areas.",
            "Highlights specific projects from Milan, Singapore, and New York."
        ])
        cityArticle.encodeExtracts([
            Extract(label: "Vertical Garden Coverage", value: "~60%"),
            Extract(label: "Integrated Solar Panel Efficiency", value: "~28%"),
            Extract(label: "Targeted Carbon Reduction", value: "~45%"),
        ])

        let restaurant = ContentItem(
            createdAt: date("2025-11-22T07:45:00"),
            contentKind: .media
        )
        restaurant.title = "Mon Ami Gabi"
        restaurant.processingStatus = ProcessingStatus.completed.rawValue
        restaurant.encodeSummaryBullets([
            "Menu is a restaurant menu"
        ])

        let projects = ContentItem(
            createdAt: date("2026-08-05T13:15:00"),
            contentKind: .note
        )
        projects.title = "Weekend Project Ideas"
        projects.processingStatus = ProcessingStatus.completed.rawValue
        projects.encodeSummaryBullets([
            "Strengths exercises for weekend",
            "Project ideas for home improvement"
        ])

        let tagUrban = Tag(name: "urban planning")
        let tagSustain = Tag(name: "sustainability")
        let tagFuture = Tag(name: "future cities")
        let tagArch = Tag(name: "architecture")
        let tagDesignboom = Tag(name: "designboom")
        let tagAI = Tag(name: "ai summary")

        cityArticle.tags = [tagUrban, tagSustain, tagFuture, tagArch, tagDesignboom, tagAI]

        [wwdc, cityArticle, restaurant, projects].forEach { context.insert($0) }
        [tagUrban, tagSustain, tagFuture, tagArch, tagDesignboom, tagAI].forEach { context.insert($0) }
    }

    private static func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        return f.date(from: iso) ?? Date()
    }
}
```

Call `SeedData.populate(context)` in `PhathomApp.swift` on first launch (check if the store is empty), and in `#Preview` blocks for SwiftUI previews.

---

## PhathomApp.swift — Updated Entry Point

```swift
import SwiftUI
import SwiftData

@main
struct PhathomApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ContentItem.self,
            Tag.self,
            ChatThread.self,
            ChatMessage.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onAppear { seedIfEmpty() }
        }
        .modelContainer(sharedModelContainer)
    }

    @MainActor
    private func seedIfEmpty() {
        let context = sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<ContentItem>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        if count == 0 {
            SeedData.populate(context)
        }
    }
}
```

---

## Acceptance Criteria

Phase 1 is complete when ALL of the following are true:

- [ ] The app compiles and runs in Simulator (**iPhone 16 Pro or newer**, e.g. iPhone 16 Pro or iPhone 17 Pro) without errors
- [ ] `Item.swift` and the template `ContentView.swift` are deleted
- [ ] All four SwiftData models (`ContentItem`, `Tag`, `ChatThread`, `ChatMessage`) are registered in the `ModelContainer`
- [ ] The tab bar shows 4 tabs: Library (selected by default), Chat, Add new, Settings
- [ ] The Library tab displays "Recent items" with a large title and filter pills
- [ ] Tapping filter pills correctly filters the list by content kind
- [ ] The list shows 4 seed items matching the mockup data (WWDC24, Future City, Mon Ami Gabi, Weekend Projects)
- [ ] The WWDC24 row shows a granular status meta chip while processing (e.g., Queued / Preparing analysis / Generating summary / Creating tags — exact label depends on seed `processingStatus`)
- [ ] Completed rows show title, domain/description, and timestamp — no badge
- [ ] Rows without thumbnail data show a colored fallback with a content-kind icon
- [ ] Tapping a row pushes to the Detail screen
- [ ] The Detail screen shows: hero, domain, title, timestamp, AI Summary bullets, Tags, Extracts, action buttons, source content — matching the mockup layout
- [ ] The "Visit Site" button appears on the hero for `.web` items
- [ ] Tags display as horizontally wrapping chips
- [ ] **Archive**: tapping Archive on the detail screen removes the item from the library list immediately, pops back to the library, and shows an undo affordance (~5s); **Recently Deleted** under Settings lists archived items with restore / delete permanently and optional countdown copy
- [ ] **Purge**: expired archived items (`archivedAt` older than 48h, still `isArchived`) are permanently removed when the app becomes active / `MainTabView` appears (see spec — Phase 2 adds BG refresh purge)
- [ ] Chat and Add new tabs show placeholder content
- [ ] The Settings tab includes **Recently Deleted** (and basic about/version — model UI is Phase 2)
- [ ] The app uses system dark mode correctly (no hardcoded colors)
- [ ] SwiftUI Previews work for the library and detail screens

---

## Out of Scope — Do NOT Build These

- Share sheet extension
- Background processing (BGTaskScheduler)
- Real web scraping or AI summarization
- Llama.cpp or FoundationModels integration
- Real thumbnail fetching (OG image scraping)
- iCloud sync
- Voice memo capture
- Any third-party dependencies

---

## Open Questions — Agent Discretion

The implementing agent MAY decide on their own:

- Exact spacing, padding, and font size adjustments to match the mockup feel
- Animation transitions between tabs and navigation pushes
- Whether to use `LazyVStack` vs `List` for the library (both are valid; `List` gives swipe actions for free)
- How to structure the "Add New" placeholder (simple form with title + URL field is fine)
- Whether `DetailView` sections use `Section` in a `List` or are manual `VStack` blocks in a `ScrollView`

The implementing agent MUST escalate / ask before:

- Adding any new SwiftData model properties **not** in this spec **and not** logged in `docs/decisions.md`
- Adding any third-party Swift packages
- Changing the tab structure or navigation hierarchy
- Modifying the `ContentItem` schema in any way
