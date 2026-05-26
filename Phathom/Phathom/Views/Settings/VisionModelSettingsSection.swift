import PhotosUI
import PhathomCore
import SwiftUI

/// Production vision model picker (text GGUF + mmproj) and Settings smoke test.
struct VisionModelSettingsSection: View {
    let textState: ModelManager.SelectionDisplayState
    let mmprojState: ModelManager.SelectionDisplayState
    let testPhase: VisionModelSettingsSection.TestPhase
    let showTestResponse: Binding<Bool>
    let hasAnyBookmark: Bool
    let isTestRunning: Bool
    let canRunTest: Bool
    @Binding var disclosureExpanded: Bool
    @Binding var testJPEG: Data?
    let onPickTextGGUF: () -> Void
    let onPickMmproj: () -> Void
    let onTest: () -> Void
    let onForget: () -> Void

    @State private var photoItem: PhotosPickerItem?

    enum TestPhase: Equatable {
        case idle
        case running
        case succeeded(summary: String, raw: String)
        case failed(message: String)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $disclosureExpanded) {
            VStack(alignment: .leading, spacing: 0) {
                settingsGroupedInteriorDivider

                visionFileBlock(
                    title: "Text GGUF",
                    state: textState,
                    emptyHint: "Pick a vision-capable text GGUF paired with an mmproj below.",
                    onSelect: onPickTextGGUF
                )

                settingsGroupedInteriorDivider

                visionFileBlock(
                    title: "mmproj",
                    state: mmprojState,
                    emptyHint: "Pick the mmproj file that matches the text GGUF above.",
                    onSelect: onPickMmproj
                )

                settingsGroupedInteriorDivider

                VStack(alignment: .leading, spacing: 12) {
                    PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                        Label(
                            testJPEG == nil ? "Choose test photo" : "Replace test photo",
                            systemImage: "photo"
                        )
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppPalette.accent)
                    }
                    .onChange(of: photoItem) { _, item in
                        Task { await loadPhoto(item) }
                    }

                    SettingsModelActionRow(
                        title: "Test vision model",
                        iconName: "play.fill",
                        iconTint: AppPalette.textPrimary,
                        foreground: AppPalette.textPrimary,
                        disabled: isTestRunning || !canRunTest,
                        action: onTest
                    )

                    if case .idle = testPhase {
                        EmptyView()
                    } else {
                        visionTestPhaseRows
                    }
                }
                .padding(.horizontal, SettingsCardCell.horizontalPadding)
                .padding(.vertical, SettingsCardCell.verticalPadding)

                if hasAnyBookmark {
                    settingsGroupedInteriorDivider
                    SettingsModelActionRow(
                        title: "Forget vision model",
                        iconName: "trash.fill",
                        iconTint: Color.red,
                        foreground: Color.red,
                        disabled: false,
                        action: onForget
                    )
                    .padding(.horizontal, SettingsCardCell.horizontalPadding)
                }

                if ModelManager.hasReadableVisionSelection {
                    settingsGroupedInteriorDivider
                    SettingsModelInfoFooter(
                        text: "Used to describe photos saved after a vision model is configured. Unloads primary and tagging models while running."
                    )
                    .padding(.horizontal, SettingsCardCell.horizontalPadding)
                    .padding(.vertical, SettingsCardCell.verticalPadding)
                }
            }
            .padding(.bottom, 8)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Vision model")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.textPrimary)
                Text("(optional)")
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.textSecondary)
                Spacer(minLength: 8)
                visionSelectionIndicator
            }
            .padding(.vertical, SettingsCardCell.verticalPadding)
            .contentShape(Rectangle())
        }
        .padding(.horizontal, SettingsCardCell.horizontalPadding)
        .tint(AppPalette.accent)
    }

    @ViewBuilder
    private var visionSelectionIndicator: some View {
        if ModelManager.hasReadableVisionSelection {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .imageScale(.medium)
                .accessibilityLabel("Vision model ready")
        } else if hasAnyBookmark {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .imageScale(.medium)
                .accessibilityLabel("Vision model incomplete or missing files")
        } else {
            Image(systemName: "circle")
                .foregroundStyle(AppPalette.textSecondary)
                .imageScale(.medium)
                .accessibilityLabel("Vision model not selected")
        }
    }

    @ViewBuilder
    private func visionFileBlock(
        title: String,
        state: ModelManager.SelectionDisplayState,
        emptyHint: String,
        onSelect: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                switch state {
                case .noSelection:
                    Text(emptyHint)
                        .foregroundStyle(AppPalette.textSecondary)
                case .ready(let name, let byteString):
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.footnote)
                            .foregroundStyle(AppPalette.textSecondary)
                        SettingsModelFileInfoBlock(fileName: name, byteString: byteString)
                    }
                case .missingFile:
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(title) file not found")
                            .foregroundStyle(.orange)
                        Text("Re-pick the file or forget this selection.")
                            .font(.footnote)
                            .foregroundStyle(AppPalette.textSecondary)
                    }
                }
            }
            .padding(.horizontal, SettingsCardCell.horizontalPadding)
            .padding(.vertical, SettingsCardCell.verticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)

            settingsGroupedInteriorDivider

            SettingsModelActionRow(
                title: visionSelectRowTitle(for: state, fileLabel: title),
                iconName: "arrow.down.doc.fill",
                iconTint: AppPalette.accent,
                foreground: AppPalette.accent,
                disabled: false,
                action: onSelect
            )
            .padding(.horizontal, SettingsCardCell.horizontalPadding)
        }
    }

    @ViewBuilder
    private var visionTestPhaseRows: some View {
        switch testPhase {
        case .idle:
            EmptyView()
        case .running:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Running vision test…")
                    .font(.footnote)
                    .foregroundStyle(AppPalette.textSecondary)
            }
        case .succeeded(let summary, let raw):
            VStack(alignment: .leading, spacing: 8) {
                Label(summary, systemImage: "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.green)
                DisclosureGroup("Show description", isExpanded: showTestResponse) {
                    Text(raw)
                        .font(.footnote)
                        .foregroundStyle(AppPalette.textSecondary)
                        .textSelection(.enabled)
                        .padding(.top, 6)
                }
                .font(.footnote)
            }
        case .failed(let message):
            Label(message, systemImage: "xmark.circle.fill")
                .font(.footnote)
                .foregroundStyle(.red)
        }
    }

    private var settingsGroupedInteriorDivider: some View {
        Divider()
            .overlay(AppPalette.textTertiary.opacity(0.35))
    }

    private func visionSelectRowTitle(
        for state: ModelManager.SelectionDisplayState,
        fileLabel: String
    ) -> String {
        switch state {
        case .noSelection:
            return "Select \(fileLabel.lowercased())"
        case .ready, .missingFile:
            return "Select different \(fileLabel.lowercased())"
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        let jpeg = MediaImageEncoding.normalizedJPEG(from: data, maxDimension: 1600, quality: 0.82) ?? data
        await MainActor.run { testJPEG = jpeg }
    }
}
