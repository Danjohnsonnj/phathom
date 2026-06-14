import PhathomCore
import Foundation

public struct GenerationOptions: Sendable {
    public var maxTokens: Int
    public var temperature: Double

    public nonisolated init(maxTokens: Int = 512, temperature: Double = 0.2) {
        self.maxTokens = maxTokens
        self.temperature = temperature
    }
}
