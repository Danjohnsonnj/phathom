# Debugging: Recently Deleted Freeze / Crash

## Status (resolved)

**Outcome:** The hang/freeze when opening **Settings → Recently Deleted** is **addressed in the current app**.

**What changed in code** (`RecentlyDeletedView.swift`):

- **`ScrollView` + `LazyVStack`** instead of **`List`** for archived rows — avoids `List` cell reuse + nested card layout churn.
- **`FetchDescriptor.fetchLimit`** (300) — caps in-memory rows for the archived query (48h retention rarely exceeds this on device).
- **`ContentCardRow(..., chrome: .plain)`** — thumbnail + text without the extra card surface padding/background that previously stacked inside a list row.

**Historical note:** The investigation below (hypotheses, Instruments workflows) remains useful if similar symptoms appear elsewhere (e.g. other screens that decode large `thumbnailData` on the main thread).

---

## 1. Problem statement (historical)

**Symptom:** Tapping **Settings > Recently Deleted** could freeze the UI (app becomes unresponsive) or crash outright, on both Simulator and device.

**UI path:** Library toolbar gear icon > `SettingsContent` > `NavigationLink` to `RecentlyDeletedView`.

**Prior code hotspots (pre-fix):**

| File | Issue |
|---|---|
| `RecentlyDeletedView.swift` | `List` + `ForEach` with full `ContentCardRow` card chrome inside each row |
| `ContentCardRow.swift` | Card padding/background/clip nested inside `List` cells |
| `ThumbnailFallback.swift` | `UIImage(data:)` on the main thread for every row’s `thumbnailData` |

---

## 2. Observed profiler run (Time Profiler)

An initial Time Profiler capture showed approximately **1 second of CPU over a 16-second window**, concentrated at startup. The **Hangs** instrument showed no graph in that run.

**Interpretation:**

- The capture likely did not include the window between tapping "Recently Deleted" and the freeze becoming visible. Time Profiler samples **running** code; a thread that is **blocked** (waiting on a lock, a synchronous decode, or a deadlocked main actor) looks **quiet**, not hot.
- A freeze with low CPU is consistent with the main thread being **stalled** rather than busy — for example, a large synchronous `UIImage(data:)` decode, or a layout pass that triggers repeated measure cycles.
- To capture the freeze itself, recording must begin **before** the tap and continue through the hang. Section 5 below explains exactly how to do this.

---

## 3. Hypotheses to test

| Priority | Hypothesis | What would confirm it |
|---|---|---|
| H1 | **Main-thread image decode.** Large `thumbnailData` blobs are decoded via `UIImage(data:)` synchronously for every visible row. With many archived items, the cumulative decode time blocks the main thread long enough to freeze. | Time Profiler or Pause (section 5-A) shows `ImageIO` / `UIImage(data:)` / `CGImageSource` frames on the main thread during the post-tap interval. Freeze goes away when thumbnails are removed or replaced with placeholders. |
| H2 | **SwiftUI List + nested card layout churn.** `ContentCardRow` applies its own padding, background, and clip shape inside a `List` row (which already has its own cell chrome). This card-inside-a-cell pattern can cause redundant layout passes, especially when combined with `.frame(maxWidth: .infinity)`. | Pause / Instruments shows deep SwiftUI layout stacks (`AG::Graph::UpdateValue`, `ViewGraph.updateOutputs`) during interaction. Replacing the card with a minimal `Text` row, or switching from `List` to `ScrollView` + `LazyVStack`, eliminates the freeze. |
| H3 | **Memory pressure / jetsam from many archived items.** Each `ContentItem` carries `thumbnailData`, `rawText`, and other blobs. Fetching all archived items at once may spike memory beyond the app's jetsam limit. | Xcode's **Memory** debug gauge shows a sharp spike when entering the screen. Reducing the number of archived items (or limiting the fetch) prevents the crash. |
| H4 | **Edge data — nil `archivedAt` in sort.** The `@Query` sorts by `\.archivedAt` descending. If an item was archived through a code path that did not set `archivedAt`, the nil value could produce unexpected sort behavior or a predicate evaluation issue. | Inspect the SwiftData store for any `ContentItem` where `isArchived == true` but `archivedAt` is nil. This is unlikely if all archives flow through `ArchiveRetention.archive(_:)` (which always sets `archivedAt = Date()`), but worth confirming by querying the database. |

---

## 4. Agent workflow (MCP-first, repo second)

This section is for the Cursor agent (you) working inside the IDE. It describes what the agent can and cannot automate.

### What the agent can do

**Before any MCP call**, read the tool's JSON schema under `.cursor/projects/.../mcps/user-xcode-tools/tools/` to confirm required parameters and types.

| MCP tool | Use |
|---|---|
| `BuildProject` | Verify the app still compiles after experimental changes. |
| `GetBuildLog` | Read build output for errors or warnings. |
| `XcodeListNavigatorIssues` | Check for runtime warnings or build diagnostics using the user's `tabIdentifier`. |

**Repo-level investigation:**

- Read and search `RecentlyDeletedView.swift`, `ContentCardRow.swift`, `ThumbnailFallback.swift`, and `ArchiveRetention.swift` for the patterns described in section 3.
- Grep for other callers of `UIImage(data:)` to assess whether the problem extends beyond thumbnails.
- Check `ContentItem` model definition for blob sizes, optional fields, and fetch descriptors.

### What the agent cannot do

The Xcode MCP cannot launch or control **Instruments**, the **debugger Pause** button, or the **Debug navigator**. Profiling and thread inspection require the user to operate the Xcode GUI directly. The user workflows below cover this.

---

## 5. User workflow

### Prerequisites

- **Xcode** is a Mac application (not to be confused with the **Simulator**, which is a separate app that Xcode launches). You need Xcode installed from the Mac App Store.
- When you run an app from Xcode, a second application called **Simulator** opens on your Mac to show the iPhone screen. Xcode and Simulator are separate windows — you will switch between them.
- **Instruments** is a third application that Xcode can launch for performance profiling. It opens in its own window.
- The project file is **`Phathom.xcodeproj`** inside the `Phathom/` subdirectory of the repo root.

### A. Reproduce and pause (no Instruments needed)

**Goal:** Capture a stack trace of the frozen main thread so the agent (or you) can see exactly where execution is stuck.

1. Open **`Phathom.xcodeproj`** in Xcode by double-clicking it in Finder, or from Xcode via **File > Open** and navigating to the file.
2. Near the top center of the Xcode window, you will see a **scheme and destination bar** (e.g. "Phathom > iPhone 17"). Click the destination portion (right side) and choose a simulator such as **iPhone 17**. If the scheme portion (left side) does not say "Phathom", click it and select **Phathom**.
3. Press the **Run** button — it is the right-pointing triangle (▶) in the top-left toolbar area. You can also press **Cmd+R**.
4. Wait until the progress spinner in Xcode's top-center status area finishes and the Simulator app appears showing the Phathom Library screen.
5. In the **Simulator**, navigate to the freeze: tap the **gear icon** in the Library toolbar to open Settings, then tap **Recently Deleted**.
6. If the screen freezes (taps do nothing, the UI is stuck), **switch back to Xcode** (click its window or use Cmd+Tab).
7. In Xcode's toolbar, click the **Pause** button — it looks like two vertical bars (‖) and sits to the right of the Stop (■) button. This suspends the app and lets you inspect threads.
8. The **Debug navigator** should appear on the left side of Xcode, showing a list of threads. If you do not see it, open it from the menu: **View > Navigators > Debug Navigator** (or press **Cmd+7**).
9. In the thread list, look for **Thread 1 (main thread)** — it is usually at the top and may be highlighted. Click it.
10. The center pane will show a **stack trace**: a list of function calls. Look for frames mentioning `UIImage`, `ImageIO`, `CGImageSource`, `SwiftUI` layout functions, or Phathom's own types like `ThumbnailView` or `ContentCardRow`.
11. **Capture the stack trace:** Take a screenshot (**Cmd+Shift+4**, drag over the stack trace area) or select the visible text, copy it (**Cmd+C**), and paste it into a text file.
12. Press the **Stop** button (■) to end the debug session.

**If something goes wrong:**

- **Run button is grayed out:** Make sure a simulator destination is selected in the scheme bar (step 2).
- **App does not freeze:** The issue may be data-dependent. Check how many items are in Recently Deleted. If there are only one or two, archive more items from the Library, wait a moment, and try again.
- **Pause button not visible:** The debug toolbar only appears after the app is running. Make sure you pressed Run first.

### B. Time Profiler

**Goal:** Record a timeline of where the CPU spends time during the tap into Recently Deleted, so you can identify whether image decoding or layout dominates.

1. In Xcode, make sure the Phathom scheme and a simulator destination are selected (same as step A-2).
2. In Xcode's menu bar, click **Product > Profile** (or press **Cmd+I**). Xcode will build the app. Wait until the build finishes — the progress indicator in Xcode's top center will stop.
3. A separate application called **Instruments** will open, showing a template chooser. If it does not open, check Xcode's status area for a build error and fix it first.
4. In the Instruments template chooser, select **Time Profiler** (it has a clock icon) and click **Choose**.
5. Instruments will show a mostly empty timeline. Click the red **Record** button (a filled circle) in the top-left of the Instruments toolbar.
6. The Simulator will launch the app. **Do not tap anything yet** — let the app finish launching so startup noise does not obscure your data.
7. In the **Simulator**, navigate to Settings > Recently Deleted to trigger the freeze or slowness.
8. After you have observed the freeze (or waited at least 5-10 seconds on the frozen screen), switch back to **Instruments** and click the **Stop** button (a square) in the Instruments toolbar.
9. **Narrow the timeline to the freeze window:** In the timeline at the top of the Instruments window, click and drag horizontally across the time range where you tapped Recently Deleted. This highlights a selection and the detail pane below updates to show only that interval's call stacks.
10. In the detail pane, expand the call tree to look for heavy frames — especially anything under `ImageIO`, `UIImage`, `CoreGraphics`, `SwiftUI`, or Phathom's own modules.
11. Take a screenshot or use **File > Save** in Instruments to save the `.trace` file for later reference.

**If something goes wrong:**

- **Profile menu is grayed out:** Select the Phathom scheme and a valid simulator destination.
- **Instruments did not open:** A build error likely occurred. Switch back to Xcode and check the Issue navigator (**Cmd+5**) for errors.
- **Timeline is empty or very short:** Make sure you clicked Record before navigating in the Simulator.

### C. Hangs instrument

**Goal:** Specifically detect main-thread hangs (periods where the main thread is unresponsive for >250ms), which complements the Time Profiler by capturing blocked/waiting time, not just CPU-busy time.

1. Follow steps B-1 through B-3 to open Instruments via **Product > Profile**.
2. In the template chooser, select **Hangs** instead of Time Profiler.
3. Click **Choose**, then **Record**, and proceed exactly as in steps B-6 through B-9.
4. After stopping, the timeline will show colored bars for any detected hangs. Click on a hang bar to see the associated stack trace in the detail pane below.
5. Screenshot or save the trace file.

**Key difference from Time Profiler:** The Hangs instrument is specifically designed to find intervals where the main thread is blocked — even if CPU usage is low. If the freeze is caused by a synchronous decode or a lock, Hangs will surface it while Time Profiler may show the interval as quiet.

### D. What to send the agent

After completing any of the procedures above, provide the following to the Cursor agent:

1. **Stack trace text** (from procedure A) — copy-pasted or screenshot.
2. **Instruments screenshot** (from B or C) — showing the narrowed timeline and the heaviest call tree frames.
3. **Instruments trace file** (`.trace`) if you saved one — the agent can reference it even if it cannot open Instruments itself.
4. **Approximate number of rows** in Recently Deleted at the time of the freeze.
5. **Device or Simulator** — which one you tested on, and if device, which model and iOS version.

---

## 6. Mitigations (historical — largely applied)

These were the likely code changes once profiling confirmed one or more hypotheses. **The current Recently Deleted implementation applies the scroll pattern, fetch limit, and plain row chrome** (see **Status** above). Further mitigations if thumbnails remain hot:

- **Async thumbnail decoding:** Move `UIImage(data:)` into a `.task {}` modifier with a `@State` image, downsample to display size using `CGImageSourceCreateThumbnailAtIndex`, and show a placeholder color during decode.
- **Lightweight row for Recently Deleted:** Using **`ContentCardRow` chrome `.plain`** avoids stacking full card chrome inside scroll rows.
