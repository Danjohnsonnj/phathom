import CoreSpotlight
import Foundation

public extension ContentItem {
    func indexInSpotlight() {
        let teaser = decodedSummaryBullets.first
            ?? mediaDescription.flatMap { s in
                let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
                return t.isEmpty ? nil : t
            }
        let attrs = CSSearchableItemAttributeSet(contentType: .text)
        attrs.title = displayTitle
        attrs.contentDescription = teaser
        attrs.keywords = tags.map(\.name)
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
