import Foundation
import SwiftData

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
        cityArticle.mediaDescription = "Sustainable architecture in dense urban environments"
        cityArticle.rawText = "Full Sustainable architecture in dense urban environments"
        cityArticle.encodeSummaryBullets([
            "Comprehensive overview of new urban development models.",
            "Focus on vertical farming and integrated renewable energy systems.",
            "Discussion of community spaces and transportation efficiency in high-density areas.",
            "Highlights specific projects from Milan, Singapore, and New York.",
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
        restaurant.mediaDescription = "Menu is a restaurant menu"
        restaurant.encodeSummaryBullets([
            "Menu is a restaurant menu",
        ])

        let projects = ContentItem(
            createdAt: date("2026-08-05T13:15:00"),
            contentKind: .note
        )
        projects.title = "Weekend Project Ideas"
        projects.processingStatus = ProcessingStatus.completed.rawValue
        projects.mediaDescription = "Strengths exercises for weekend, home improvement ideas"
        projects.encodeSummaryBullets([
            "Strengths exercises for weekend",
            "Project ideas for home improvement",
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
