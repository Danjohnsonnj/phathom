import Foundation

/// Stable multi-section text for Llama summarization / tagging on TikTok web captures.
public enum TikTokAIArticleText {
    /// Assembles `Author`, optional `Transcript`, and `Post caption` sections.
    public static func assemble(uniqueId: String?, description: String, transcript: String?) -> String {
        var parts: [String] = []
        if let uid = uniqueId?.trimmingCharacters(in: .whitespacesAndNewlines), !uid.isEmpty {
            parts.append("Author: @\(uid)")
        }
        if let t = transcript?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
            parts.append("Transcript:\n\(t)")
        }
        parts.append("Post caption:\n\(description)")
        return parts.joined(separator: "\n\n")
    }
}
