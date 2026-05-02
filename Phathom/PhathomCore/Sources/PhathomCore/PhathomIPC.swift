import Foundation

public enum PhathomIPC {
    /// Notify the host app that the shared store changed (e.g. Share Extension saved). Best-effort when the app is suspended.
    public static func notifyStoreChanged() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(PhathomAppGroup.storeChangedDarwinNotificationName as CFString),
            nil,
            nil,
            true
        )
    }
}
