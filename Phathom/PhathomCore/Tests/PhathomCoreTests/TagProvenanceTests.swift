import PhathomCore
import SwiftData
import XCTest

final class TagProvenanceNormalizerTests: XCTestCase {
    func testNormalizeManyDeduplicatesPreservingOrder() {
        let out = TagProvenanceNormalizer.normalizeMany(["AI", "ai", "podcast", "  podcast  "])
        XCTAssertEqual(out, ["ai", "podcast"])
    }

    func testApplyAddRecordsNormalizedName() {
        let out = TagProvenanceNormalizer.applyAdd(current: ["news"], added: "Podcast")
        XCTAssertEqual(out, ["news", "podcast"])
    }

    func testApplyAddDedupesExisting() {
        let out = TagProvenanceNormalizer.applyAdd(current: ["podcast"], added: "Podcast")
        XCTAssertEqual(out, ["podcast"])
    }

    func testApplyRenameReplacesOldName() {
        let out = TagProvenanceNormalizer.applyRename(
            current: ["old-tag", "keep"],
            from: "old-tag",
            to: "new-tag"
        )
        XCTAssertEqual(out, ["keep", "new-tag"])
    }

    func testApplyDeleteRemovesName() {
        let out = TagProvenanceNormalizer.applyDelete(current: ["aa", "bb"], removed: "aa")
        XCTAssertEqual(out, ["bb"])
    }
}

final class TagSeedBuilderProvenanceTests: XCTestCase {
    func testSubjectSeedPrioritizesUserAddedLexAscending() {
        let seed = TagSeedBuilder.selectSubjectSeed(
            userAdded: ["zebra", "alpha", "beta"],
            frequencyCandidates: [("freq", 10)],
            floor: 3,
            cap: 15
        )
        XCTAssertEqual(seed.prefix(3), ["alpha", "beta", "zebra"])
        XCTAssertTrue(seed.contains("freq"))
    }

    func testSubjectSeedRespectsCapWithUserAddedFirst() {
        let seed = TagSeedBuilder.selectSubjectSeed(
            userAdded: ["a", "b", "c"],
            frequencyCandidates: [("freq", 10)],
            floor: 1,
            cap: 2
        )
        XCTAssertEqual(seed, ["a", "b"])
    }

    func testPromotedContentTypesExcludesBaseVocabulary() {
        let promoted = TagSeedBuilder.selectPromotedContentTypes(
            provenanceCounts: [("news", 5), ("podcast", 3)],
            baseVocabulary: ["news", "opinion"],
            promotionFloor: 2,
            cap: 5
        )
        XCTAssertEqual(promoted, ["podcast"])
    }

    func testPromotedContentTypesRequiresFloorAndCaps() {
        let promoted = TagSeedBuilder.selectPromotedContentTypes(
            provenanceCounts: [
                ("low", 1),
                ("mid", 2),
                ("high", 5),
                ("extra", 4),
                ("sixth", 3),
                ("seventh", 3),
            ],
            baseVocabulary: [],
            promotionFloor: 2,
            cap: 5
        )
        XCTAssertEqual(promoted, ["high", "extra", "sixth", "seventh", "mid"])
    }
}

final class TagPipelineMergeTests: XCTestCase {
    func testMergedForUpsertUnionsLLMAndSticky() {
        let merged = TagPipelineMerge.mergedForUpsert(
            llmTags: ["ai", "news"],
            stickyTags: ["podcast", "ai"]
        )
        XCTAssertEqual(merged, ["ai", "news", "podcast"])
    }
}

final class TagRelationshipUpsertTests: XCTestCase {
    func testAttachMissingTagNamesAddsOnlyMissing() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let item = ContentItem()
        let existing = Tag(name: "news")
        context.insert(existing)
        context.insert(item)
        item.tags = [existing]

        var tagIndex: [String: Tag] = ["news": existing]
        TagRelationshipUpsert.attachMissingTagNames(
            ["news", "podcast"],
            to: item,
            tagIndex: &tagIndex,
            context: context
        )

        XCTAssertEqual(item.tagNames.sorted(), ["news", "podcast"])
        XCTAssertNotNil(tagIndex["podcast"])
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = PhathomModelContainer.currentSchema
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
