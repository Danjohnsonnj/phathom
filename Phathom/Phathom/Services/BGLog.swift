import Foundation
import os

/// Background diagnostics logger. Writes to the unified log so messages are visible in
/// **Console.app** (filter by `subsystem:com.phathom.Phathom category:background`) even when
/// the device is locked, the app is suspended, or no debugger is attached. `print` only goes to
/// the Xcode console and is invisible once the OS wakes the BG task without an attached process.
///
/// Values are marked `privacy: .public` because these are diagnostic strings (counts, identifiers,
/// scene phases, outcomes) — no PII. UUIDs that appear are internal item IDs.
enum BGLog {
    private static let logger = Logger(
        subsystem: "com.phathom.Phathom",
        category: "background"
    )

    static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }
}
