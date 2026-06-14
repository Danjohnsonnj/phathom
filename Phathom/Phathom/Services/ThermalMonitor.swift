import PhathomCore
import Foundation

public enum ThermalMonitor {
    public nonisolated static var shouldThrottle: Bool {
        ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue
    }
}
