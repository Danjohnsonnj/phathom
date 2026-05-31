import SwiftUI

enum LibraryPipelineControl {
    case pause
    case resume
}

/// Pause / resume control for Library actions row (§3.2.1) — wire in Phase 2.
struct LibraryPipelineControlButton: View {
    let control: LibraryPipelineControl
    var isSettling: Bool = false
    var resumeAccessibilityLabel: String = ""
    var resumeAccessibilityHint: String = ""
    var onPause: () -> Void
    var onResume: () -> Void

    var body: some View {
        Group {
            switch control {
            case .pause:
                Button(action: onPause) {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(AppPalette.accent)
                        .frame(width: 38, height: 38)
                }
                .accessibilityLabel("Pause processing")
                .accessibilityHint("Stop in-flight ingest and analysis")
            case .resume:
                Button(action: onResume) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(AppPalette.accent)
                        .frame(width: 38, height: 38)
                }
                .accessibilityLabel(resumeAccessibilityLabel)
                .accessibilityHint(resumeAccessibilityHint)
            }
        }
        .buttonStyle(.plain)
        .disabled(isSettling)
        .opacity(isSettling ? 0.45 : 1)
        .accessibilityValue(isSettling ? "Waiting for processing to stop" : "")
    }
}

#Preview("Pause") {
    LibraryPipelineControlButton(
        control: .pause,
        resumeAccessibilityLabel: "Resume processing",
        resumeAccessibilityHint: "Resume ingest and analysis",
        onPause: {},
        onResume: {}
    )
}

#Preview("Resume — settling") {
    LibraryPipelineControlButton(
        control: .resume,
        isSettling: true,
        resumeAccessibilityLabel: "Start queued processing",
        resumeAccessibilityHint: "Process queued items now",
        onPause: {},
        onResume: {}
    )
}
