import PhathomInference
import SwiftData
import SwiftUI

/// Archive retention, model bookmark validation, and pipeline scheduling on app lifecycle.
/// Attached once on `PhathomApp` `WindowGroup` root (iOS + macOS).
struct PipelineLifecycleModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    func body(content: Content) -> some View {
        content
            .onAppear(perform: runActiveLifecycleWork)
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    runActiveLifecycleWork()
                    BackgroundPipeline.scheduleForegroundDrain()
                case .inactive, .background:
                    BackgroundPipeline.scheduleAll()
                @unknown default:
                    break
                }
            }
    }

    private func runActiveLifecycleWork() {
        ArchiveRetention.purgeExpired(in: modelContext)
        ModelManager.validateSelection()
        ModelManager.validateTaggingSelection()
    }
}

extension View {
    func pipelineLifecycle() -> some View {
        modifier(PipelineLifecycleModifier())
    }
}
