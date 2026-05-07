import Dispatch
import Foundation
import Network

/// Triggers pipeline ingest when connectivity becomes available (e.g. after offline capture).
enum NetworkReachability {
    nonisolated(unsafe) private static var monitor: NWPathMonitor?
    nonisolated(unsafe) private static var satisfiedDrainWorkItem: DispatchWorkItem?
    nonisolated(unsafe) private static var latestStatus: NWPath.Status = .requiresConnection

    nonisolated static var hasUsableConnection: Bool {
        latestStatus == .satisfied
    }

    static func start() {
        guard monitor == nil else { return }
        let queue = DispatchQueue(label: "phathom.network", qos: .utility)
        let m = NWPathMonitor()
        m.pathUpdateHandler = { path in
            latestStatus = path.status
            satisfiedDrainWorkItem?.cancel()
            satisfiedDrainWorkItem = nil
            guard path.status == .satisfied else { return }

            let work = DispatchWorkItem {
                BackgroundPipeline.scheduleForegroundDrain()
                BackgroundPipeline.scheduleIngest()
            }
            satisfiedDrainWorkItem = work
            // Coalesce brief satisfied/unstable path updates so we do not hammer the scrape loop on device.
            queue.asyncAfter(deadline: .now() + 0.35, execute: work)
        }
        m.start(queue: queue)
        monitor = m
    }

    #if DEBUG
    /// Test-only seam to set reachability without a live `NWPathMonitor`.
    @discardableResult
    static func _test_forceStatus(_ status: NWPath.Status) -> NWPath.Status {
        let old = latestStatus
        latestStatus = status
        return old
    }
    #endif
}
