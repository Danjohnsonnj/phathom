import Foundation
import SwiftData

public enum ShareCaptureError: LocalizedError {
    case nothingToInsert

    public var errorDescription: String? {
        switch self {
        case .nothingToInsert:
            "Nothing to save."
        }
    }
}

/// Insert rules for Share Extension (capture-only; no networking or AI).
public enum ShareCapture {
    public static let mediaPlaceholderDescription = "Visual analysis is not available yet. This item was saved as a photo."

    /// Preference when both URL and plain text are present (e.g. Mail).
    public enum URLTextPrecedence {
        /// One `ContentItem` web row from URL; body text is ignored for v1.
        case urlOnly
    }

    /// Save a photo to the library (completed, no LLM). Caller should pass JPEG data (e.g. from `MediaImageEncoding` on iOS).
    public static func insertMediaItem(context: ModelContext, imageJPEGData: Data, title: String? = nil) throws {
        let item = ContentItem(contentKind: .media, originalURL: nil)
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        item.title = (trimmed?.isEmpty == false) ? trimmed : nil
        item.titleUserSet = item.title != nil
        item.thumbnailData = imageJPEGData
        item.mediaDescription = mediaPlaceholderDescription
        item.rawText = nil
        item.processingStatus = ProcessingStatus.completed.rawValue
        item.processingDetail = nil
        item.failureReason = nil
        context.insert(item)
        try context.save()
        item.indexInSpotlight()
    }

    public static func insertFromShare(
        context: ModelContext,
        sharedURL: URL?,
        plainText: String?,
        imageJPEGData: Data? = nil,
        urlTextPrecedence: URLTextPrecedence = .urlOnly
    ) throws {
        if let url = sharedURL {
            switch urlTextPrecedence {
            case .urlOnly:
                try insertWebItem(context: context, url: url)
            }
            return
        }

        if let jpeg = imageJPEGData, !jpeg.isEmpty {
            try insertMediaItem(context: context, imageJPEGData: jpeg)
            return
        }

        guard let text = plainText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            throw ShareCaptureError.nothingToInsert
        }

        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let singleNonEmpty = lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if singleNonEmpty.count == 1,
           let u = URL(string: singleNonEmpty[0].trimmingCharacters(in: .whitespacesAndNewlines)),
           u.scheme != nil {
            try insertWebItem(context: context, url: u)
            return
        }

        try insertNoteItem(context: context, rawMarkdown: text)
    }

    private static func insertWebItem(context: ModelContext, url: URL) throws {
        let item = ContentItem(contentKind: .web, originalURL: url)
        item.title = nil
        item.processingStatus = ProcessingStatus.pending.rawValue
        item.processingDetail = "Queued for capture"
        context.insert(item)
        try context.save()
    }

    private static func insertNoteItem(context: ModelContext, rawMarkdown: String) throws {
        let trimmed = rawMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = ContentItem(contentKind: .note)
        let firstLine = trimmed.split(separator: "\n", omittingEmptySubsequences: false).first.map(String.init) ?? ""
        let plain = MarkdownNoteHelpers.plainTitleLine(from: firstLine)
        item.title = plain.isEmpty ? "Untitled note" : String(plain.prefix(80))
        item.rawText = trimmed
        item.mediaDescription = String(trimmed.prefix(120))
        item.processingStatus = ProcessingStatus.embedding.rawValue
        item.processingDetail = "Preparing analysis…"
        context.insert(item)
        try context.save()
    }
}
