import CoreSpotlight
import Foundation

public extension ContentItem {
    func indexInSpotlight() {
        let teaser = displaySummaryBullets.first
            ?? mediaDescription.flatMap { s in
                let t = SummaryLineSanitization.sanitizedBullet(s)
                return t.isEmpty ? nil : t
            }
        let attrs = CSSearchableItemAttributeSet(contentType: .text)
        attrs.title = displayTitle
        attrs.contentDescription = teaser
        // Keywords are tag names only for now; structural `category` is intentionally omitted until
        // product wants system-wide category search (`applyCategory` still reindexes for title/teaser/tags).
        attrs.keywords = tagNames
        if let data = thumbnailData {
            attrs.thumbnailData = data
        }

        let searchable = CSSearchableItem(
            uniqueIdentifier: id.uuidString,
            domainIdentifier: "com.phathom.library",
            attributeSet: attrs
        )
        CSSearchableIndex.default().indexSearchableItems([searchable]) { _ in }
    }

    func removeFromSpotlight() {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [id.uuidString]) { _ in }
    }
}
