import Foundation

struct Extract: Codable, Identifiable, Hashable {
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
