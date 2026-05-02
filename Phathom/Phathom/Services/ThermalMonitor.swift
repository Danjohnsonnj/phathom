import PhathomCore
import Foundation

enum ThermalMonitor {
    nonisolated static var shouldThrottle: Bool {
        ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue
    }
}
