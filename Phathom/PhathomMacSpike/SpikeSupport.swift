import Darwin
import Foundation

enum SpikeError: LocalizedError {
    case missingEnv(String)
    case missingFixture(String)
    case stepFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingEnv(let key):
            "Missing required environment variable: \(key)"
        case .missingFixture(let path):
            "Fixture not found: \(path)"
        case .stepFailed(let message):
            message
        }
    }
}

enum SpikeMemory {
    private nonisolated(unsafe) static var peakFootprintBytes: UInt64 = 0

    nonisolated static func resetPeakTracking() {
        peakFootprintBytes = 0
    }

    nonisolated static func recordSample() {
        peakFootprintBytes = max(peakFootprintBytes, residentBytes())
    }

    nonisolated static func peakMegabytes() -> Double {
        Double(peakFootprintBytes) / 1_048_576.0
    }

    nonisolated static func residentMegabytes() -> Double {
        Double(residentBytes()) / 1_048_576.0
    }

    nonisolated static func residentBytes() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), intPtr, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return 0 }
        return info.phys_footprint
    }
}

enum SpikePaths {
    nonisolated static func requireEnv(_ key: String) throws -> String {
        guard let value = ProcessInfo.processInfo.environment[key], !value.isEmpty else {
            throw SpikeError.missingEnv(key)
        }
        return value
    }

    nonisolated static func fixturePath(_ name: String, envKey: String) throws -> String {
        if let override = ProcessInfo.processInfo.environment[envKey], !override.isEmpty {
            return override
        }
        let parts = name.split(separator: ".", maxSplits: 1).map(String.init)
        if parts.count == 2,
           let bundled = Bundle.main.url(forResource: parts[0], withExtension: parts[1])
        {
            return bundled.path
        }
        let sourceRelative = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/\(name)")
        if FileManager.default.fileExists(atPath: sourceRelative.path) {
            return sourceRelative.path
        }
        throw SpikeError.missingFixture(name)
    }
}

enum SpikeReporter {
    nonisolated static func logStep(_ index: Int, _ name: String, wallSeconds: TimeInterval, peakMB: Double, detail: String) {
        let line = String(
            format: "[PhathomMacSpike] step=%d name=%@ wall_s=%.2f peak_mb=%.1f %@",
            index,
            name,
            wallSeconds,
            peakMB,
            detail
        )
        print(line)
    }
}
