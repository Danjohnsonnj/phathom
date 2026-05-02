import Foundation
import SwiftData

@Model
public final class ChatThread {
    public var id: UUID
    public var topic: String
    public var createdAt: Date
    @Relationship public var messages: [ChatMessage] = []
    @Relationship public var sourceTags: [Tag] = []

    public init(topic: String, sourceTags: [Tag] = []) {
        self.id = UUID()
        self.topic = topic
        self.createdAt = Date()
        self.sourceTags = sourceTags
    }
}
