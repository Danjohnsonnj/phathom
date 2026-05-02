import PhathomCore
import Foundation

struct GenerationOptions: Sendable {
    var maxTokens: Int
    var temperature: Double

    nonisolated init(maxTokens: Int = 512, temperature: Double = 0.2) {
        self.maxTokens = maxTokens
        self.temperature = temperature
    }
}
