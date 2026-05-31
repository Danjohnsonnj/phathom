import CoreGraphics

/// Cross-surface layout rhythm (design-tokens.md §3).
enum AppSpacing {
    /// Default content inset — tab roots, Detail, Add New, Notebook, Chat, Settings.
    static let screenHorizontal: CGFloat = 22

    /// Pushed Detail / Settings nav chrome (mock `.detail-nav` vertical padding).
    static let pushNavBarTop: CGFloat = 4
    static let pushNavBarBottom: CGFloat = 8

    /// Between major section groups (Settings zones, Add New stack).
    static let sectionVerticalGap: CGFloat = 24

    /// Margin below screen-owned large title before first section.
    static let editorialTitleBottom: CGFloat = 28

    /// Detail AI zone: gap before subsection hairline + gap from hairline to subsection header (mock `.ai-subsection + .ai-subsection`).
    static let aiSubsectionHairlineGap: CGFloat = 22

    /// Detail hairline sections: inset below top hairline (spaced blocks + action CTAs). Matches ai-zone bottom → action hairline gap (last Key Figures row to line).
    static let detailSectionAfterHairlineGap: CGFloat = 20

    /// Bottom padding so list scrolls under liquid-glass tab bar.
    static let tabBarScrollInset: CGFloat = 104

    /// Library gallery row vertical padding.
    static let galleryRowVertical: CGFloat = 19

    /// Vertical gap between highlights within the same Notebook item (no hairline).
    static let highlightStackGap: CGFloat = 14

    /// Notebook feed: top inset on first item group header (empty copy uses same band).
    static let notebookGroupHeaderTop: CGFloat = 16

    /// Gap below `LibraryFilterBar` before feed or empty copy (mock `filter-bar` margin-bottom).
    static let filterBarBottom: CGFloat = 22

    /// Library `LibraryFilterBar` stable height.
    static let filterBarHeight: CGFloat = 72

    /// Library filter column ratio (27.5% / 27.5% / 45%) — owned by `LibraryFilterBar`; do not change (Phase 2).

    /// Grouped Settings surfaces, Add New capture card.
    static let cardCornerRadius: CGFloat = 14

    /// Library / Notebook 64×64 thumbs.
    static let thumbCornerRadius: CGFloat = 6

    /// Add New Save, Detail Visit Site pill.
    static let capsuleCTAHeight: CGFloat = 50

    /// Add New segmented mode bar (+ 4pt inner inset).
    static let modePillOuterRadius: CGFloat = 26
}
