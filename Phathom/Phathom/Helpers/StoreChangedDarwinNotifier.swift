import CoreFoundation
import Foundation
import PhathomCore

/// Bridges Darwin notify (Share Extension save) to a main-actor pipeline drain.
enum StoreChangedDarwinNotifier {
    private final class Bridge {
        func start() {
            let center = CFNotificationCenterGetDarwinNotifyCenter()
            let name = PhathomAppGroup.storeChangedDarwinNotificationName as CFString
            CFNotificationCenterAddObserver(
                center,
                Unmanaged.passUnretained(self).toOpaque(),
                { _, observer, _, _, _ in
                    guard let observer else { return }
                    Unmanaged<Bridge>.fromOpaque(observer).takeUnretainedValue().handle()
                },
                name,
                nil,
                .deliverImmediately
            )
        }

        private func handle() {
            Task { @MainActor in
                BackgroundPipeline.scheduleForegroundDrain()
            }
        }
    }

    private static let bridge = Bridge()

    static func start() {
        bridge.start()
    }
}
