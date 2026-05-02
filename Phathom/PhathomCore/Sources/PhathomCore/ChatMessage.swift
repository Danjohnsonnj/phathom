import Foundation
import SwiftData

@Model
public final class ChatMessage {
    public var role: String
    public var text: String
    public var timestamp: Date

    public init(role: String, text: String) {
        self.role = role
        self.text = text
        self.timestamp = Date()
    }
}
