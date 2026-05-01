import CoreSpotlight
import Foundation

extension ContentItem {
    func indexInSpotlight() {
        let attrs = CSSearchableItemAttributeSet(contentType: .text)
        attrs.title = title
        attrs.contentDescription = decodedSummaryBullets.first
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
