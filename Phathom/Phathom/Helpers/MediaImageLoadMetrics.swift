#if os(iOS)
import Foundation
import OSLog

/// Intervals for Detail media hero / View Photo load (`com.phathom.media` / `detail`).
enum MediaImageLoadMetrics {
    static let userDefaultsKey = "phathom.mediaImageProfiling"
    static let launchArgument = "-MediaImageProfiling"

    private static let logger = Logger(subsystem: "com.phathom.media", category: "detail")

    #if DEBUG
    private static let signposter = OSSignposter(
        logger: Logger(subsystem: "com.phathom.media", category: "detail")
    )
    #endif

    private static let consolePrefix = "[Phathom.Media]"
    private static var didLogProfilingEnabled = false
    private static var loggedCacheHitKeys: Set<String> = []
    private static let cacheHitLogLock = NSLock()

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
            || UserDefaults.standard.bool(forKey: userDefaultsKey)
    }

    static func setProfilingEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: userDefaultsKey)
    }

    /// Confirms profiling flag is active (call once at launch).
    static func logProfilingEnabledIfNeeded() {
        guard isEnabled else { return }
        cacheHitLogLock.lock()
        defer { cacheHitLogLock.unlock() }
        guard !didLogProfilingEnabled else { return }
        didLogProfilingEnabled = true

        let line = "\(consolePrefix) profiling ON (launch arg or UserDefaults \(userDefaultsKey))"
        logger.info("\(line, privacy: .public)")
        #if DEBUG
        print(line)
        #endif
    }

    static func log(_ message: String) {
        guard isEnabled else { return }
        let line = "\(consolePrefix) \(message)"
        logger.info("\(line, privacy: .public)")
        #if DEBUG
        print(line)
        #endif
    }

    static func logCacheHitIfNeeded(itemID: UUID, appearGeneration: Int) {
        guard isEnabled else { return }
        let key = "\(itemID.uuidString)-\(appearGeneration)"
        cacheHitLogLock.lock()
        defer { cacheHitLogLock.unlock() }
        guard loggedCacheHitKeys.insert(key).inserted else { return }
        log("cache_hit item=\(itemID.uuidString)")
    }

    static func clearCacheHitLog(for itemID: UUID) {
        let prefix = itemID.uuidString
        cacheHitLogLock.lock()
        defer { cacheHitLogLock.unlock() }
        loggedCacheHitKeys = loggedCacheHitKeys.filter { !$0.hasPrefix(prefix) }
    }

    static func logThumbnailFault(byteCount: Int, isJPEG: Bool, durationMs: Double) {
        guard isEnabled else { return }
        let line =
            "\(consolePrefix) thumbnail_fault bytes=\(byteCount) jpeg=\(isJPEG) ms=\(String(format: "%.2f", durationMs))"
        logger.info("\(line, privacy: .public)")
        #if DEBUG
        print(line)
        #endif
    }

    static func measure<T>(_ name: StaticString, _ work: () throws -> T) rethrows -> T {
        guard isEnabled else { return try work() }
        #if DEBUG
        let state = signposter.beginInterval(name)
        defer { signposter.endInterval(name, state) }
        #endif
        let start = ContinuousClock.now
        let value = try work()
        log("\(name) ms=\(String(format: "%.2f", durationMs(from: start)))")
        return value
    }

    static func measureAsync<T>(
        _ name: StaticString,
        _ work: () async throws -> T
    ) async rethrows -> T {
        guard isEnabled else { return try await work() }
        #if DEBUG
        let state = signposter.beginInterval(name)
        defer { signposter.endInterval(name, state) }
        #endif
        let start = ContinuousClock.now
        let value = try await work()
        log("\(name) ms=\(String(format: "%.2f", durationMs(from: start)))")
        return value
    }

    static func elapsedMilliseconds(since start: ContinuousClock.Instant) -> Double {
        let delta = ContinuousClock.now - start
        let components = delta.components
        return Double(components.seconds) * 1000
            + Double(components.attoseconds) / 1_000_000_000_000_000 * 1000
    }

    private static func durationMs(from start: ContinuousClock.Instant) -> Double {
        elapsedMilliseconds(since: start)
    }
}
#endif
