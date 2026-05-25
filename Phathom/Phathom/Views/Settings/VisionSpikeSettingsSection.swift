#if DEBUG
import PhotosUI
import PhathomCore
import SwiftUI

/// Phase 0: device VLM spike UI (Settings). Uses parent `SettingsContent` fileImporter + security-scoped bookmarks.
struct VisionSpikeSettingsSection: View {
    let onPickTextGGUF: () -> Void
    let onPickMmproj: () -> Void

    @AppStorage("phathom.visionSpike.profileOverride")
    private var profileOverrideRaw = VisionSpikeProfileOverride.automatic.rawValue

    @State private var photoItem: PhotosPickerItem?
    @State private var testJPEG: Data?
    @State private var phase: SpikePhase = .idle
    @State private var lastReport: String?

    private enum SpikePhase: Equatable {
        case idle
        case running
        case succeeded
        case failed(String)
    }

    private var profileOverride: VisionSpikeProfileOverride {
        VisionSpikeProfileOverride(rawValue: profileOverrideRaw) ?? .automatic
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Vision spike (Phase 0)")
                    .font(.headline.bold())
                    .foregroundStyle(AppPalette.textPrimary)
                Text("Experimental VLM describe — text GGUF + mmproj + photo. Run on a physical device.")
                    .font(.caption)
                    .foregroundStyle(AppPalette.textSecondary)
            }
            settingsGroupedSurface {
                VStack(alignment: .leading, spacing: 12) {
                    pathRow(kind: .textGGUF)
                    pathRow(kind: .mmproj)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Profile override")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppPalette.textPrimary)
                        Picker("Profile", selection: Binding(
                            get: {
                                VisionSpikeProfileOverride(rawValue: profileOverrideRaw) ?? .automatic
                            },
                            set: { profileOverrideRaw = $0.rawValue }
                        )) {
                            ForEach(VisionSpikeProfileOverride.allCases, id: \.rawValue) { opt in
                                Text(opt.label).tag(opt)
                            }
                        }
                        .pickerStyle(.segmented)
                        Text("Auto picks compact vs capable from GGUF filename and size.")
                            .font(.caption2)
                            .foregroundStyle(AppPalette.textSecondary)
                    }

                    PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                        Label(testJPEG == nil ? "Choose test photo" : "Replace test photo", systemImage: "photo")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppPalette.accent)
                    }
                    .onChange(of: photoItem) { _, item in
                        Task { await loadPhoto(item) }
                    }

                    Button {
                        Task { await runSpikeMain() }
                    } label: {
                        Text(phase == .running ? "Running spike…" : "Run vision describe")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppPalette.accent)
                    .disabled(!canRun)

                    if let report = lastReport {
                        Text(report)
                            .font(.caption)
                            .foregroundStyle(AppPalette.textSecondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }

    private var canRun: Bool {
        phase != .running
            && VisionSpikeStorage.hasBothReadable
            && testJPEG.map { !$0.isEmpty } == true
    }

    @ViewBuilder
    private func pathRow(kind: VisionSpikeStorage.SpikeFileKind) -> some View {
        let (name, readable) = VisionSpikeStorage.displayState(for: kind)
        let titleText = switch kind {
        case .textGGUF:
            "Text GGUF"
        case .mmproj:
            "mmproj"
        }
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(titleText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.textPrimary)
                Spacer()
                Button("Pick") {
                    switch kind {
                    case .textGGUF:
                        onPickTextGGUF()
                    case .mmproj:
                        onPickMmproj()
                    }
                }
                .font(.caption.weight(.semibold))
            }
            Text(displaySubtitle(name: name, readable: readable))
                .font(.caption)
                .foregroundStyle(readable ? AppPalette.textSecondary : AppPalette.accent.opacity(0.9))
                .lineLimit(2)
        }
    }

    private func displaySubtitle(name: String, readable: Bool) -> String {
        if !readable, name != "Not selected" {
            return "\(name) — not readable (re-pick)"
        }
        return name
    }

    private func settingsGroupedSurface<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(AppPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// Store a 1600px max baseline; spike run re-normalizes per profile caps.
    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        let jpeg = MediaImageEncoding.normalizedJPEG(from: data, maxDimension: 1600, quality: 0.82) ?? data
        await MainActor.run { testJPEG = jpeg }
    }

    /// ~10-minute wall-clock guard so UI never spins forever on native hangs.
    private static let spikeTimeoutNanoseconds: UInt64 = 600 * 1_000_000_000

    @MainActor
    private func runSpikeMain() async {
        guard let jpeg = testJPEG, !jpeg.isEmpty else { return }
        phase = .running
        lastReport = nil

        let override = profileOverride

        guard let textAccessForMeta = VisionSpikeStorage.openTextSelection() else {
            let msg = "Could not resolve vision spike text GGUF bookmark. Re-pick the file."
            phase = .failed(msg)
            lastReport = "Failed: \(msg)"
            return
        }
        defer { textAccessForMeta.end() }
        let textPathForMeta = textAccessForMeta.path
        var fileSizeBytes: UInt64?
        if let attrs = try? FileManager.default.attributesOfItem(atPath: textPathForMeta),
           let ns = attrs[.size] as? NSNumber {
            let v = ns.uint64Value
            fileSizeBytes = v == 0 ? nil : v
        }

        let merged = VisionSpikeRunConfiguration.resolveProfile(
            override: override,
            textGGUFPath: textPathForMeta,
            fileSizeBytes: fileSizeBytes
        )

        do {
            let result = try await SharedLlamaInference.shared.withVisionSpikeSession {
                try await Self.runSpikeWithTimeout(
                    jpegData: jpeg,
                    mergedProfile: merged,
                    timeoutNanoseconds: Self.spikeTimeoutNanoseconds
                )
            }
            phase = .succeeded
            lastReport = formatReport(
                result,
                effectiveProfile: merged,
                profileOverride: override
            )
        } catch {
            phase = .failed(error.localizedDescription)
            lastReport = "Failed: \(error.localizedDescription)"
        }
    }

    private static func runSpikeWithTimeout(
        jpegData: Data,
        mergedProfile: VisionSpikeProfile,
        timeoutNanoseconds: UInt64
    ) async throws -> VisionSpikeResult {
        try await withThrowingTaskGroup(of: VisionSpikeResult.self) { group in
            group.addTask {
                try await Task.detached(priority: .userInitiated) {
                    guard let textAccess = VisionSpikeStorage.openTextSelection(),
                          let mmAccess = VisionSpikeStorage.openMmprojSelection()
                    else {
                        throw VisionSpikeError.ggufBookmarksUnavailable
                    }
                    defer {
                        textAccess.end()
                        mmAccess.end()
                    }
                    let textPath = textAccess.path
                    let mmprojPath = mmAccess.path

                    let spike = LlamaVisionSpike()
                    return try spike.describeImage(
                        textModelPath: textPath,
                        mmprojPath: mmprojPath,
                        jpegData: jpegData,
                        mergedProfile: mergedProfile
                    )
                }.value
            }
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                throw VisionSpikeError.timeout
            }
            guard let first = try await group.next() else {
                throw VisionSpikeError.timeout
            }
            group.cancelAll()
            return first
        }
    }

    private func formatReport(
        _ r: VisionSpikeResult,
        effectiveProfile: VisionSpikeProfile,
        profileOverride: VisionSpikeProfileOverride
    ) -> String {
        let tokenNote = r.estimatedVisionSequenceTokens.map { "\($0)" } ?? "n/a"
        return """
        Vision: \(r.supportsVision ? "yes" : "no")
        Profile (effective): \(effectiveProfile.displayName)
        Profile (UI): \(profileOverride.label)
        Attempt: \(r.runtimeAttempt.labelForReport)
        Image cap used: \(Int(r.imageMaxDimensionApplied)) px
        GPU projector: \(r.useGPUProjector ? "yes" : "no")
        Est. sequence tokens: \(tokenNote)
        Load: \(String(format: "%.2fs", r.loadDuration))
        Eval: \(String(format: "%.2fs", r.evalDuration))
        Generate: \(String(format: "%.2fs", r.generateDuration))
        Total: \(String(format: "%.2fs", r.totalDuration))

        Description:
        \(r.description)
        """
    }
}

#endif
