import Foundation
import SwiftData

@Model
final class ChatThread {
    var id: UUID
    var topic: String
    var createdAt: Date
    @Relationship var messages: [ChatMessage] = []
    @Relationship var sourceTags: [Tag] = []

    init(topic: String, sourceTags: [Tag] = []) {
        self.id = UUID()
        self.topic = topic
        self.createdAt = Date()
        self.sourceTags = sourceTags
    }
}
