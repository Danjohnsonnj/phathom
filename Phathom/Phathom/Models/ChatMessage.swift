import Foundation
import SwiftData

@Model
final class ChatMessage {
    var role: String
    var text: String
    var timestamp: Date

    init(role: String, text: String) {
        self.role = role
        self.text = text
        self.timestamp = Date()
    }
}
