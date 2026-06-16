import PhathomCore
import PhathomInference
import SwiftUI
#if os(iOS)
import PhotosUI
#endif
import UniformTypeIdentifiers

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

    #if os(iOS)
    @State private var photoItem: PhotosPickerItem?
    #endif
    @State private var showTestImageImporter = false

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
                    #if os(iOS)
                    PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                        visionTestPhotoLabel
                    }
                    .onChange(of: photoItem) { _, item in
                        Task { await loadPhoto(item) }
                    }
                    #else
                    Button {
                        showTestImageImporter = true
                    } label: {
                        visionTestPhotoLabel
                    }
                    .buttonStyle(.plain)
                    .fileImporter(
                        isPresented: $showTestImageImporter,
                        allowedContentTypes: [.jpeg, .png, .heic, .image],
                        allowsMultipleSelection: false
                    ) { result in
                        if case .success(let urls) = result, let url = urls.first {
                            Task { await loadPhotoFromURL(url) }
                        }
                    }
                    #endif

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
                    .appTypography(.disclosureLabel)
                    .foregroundStyle(AppPalette.textPrimary)
                Text("(optional)")
                    .appTypography(.zoneSubtitle)
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
                        .appTypography(.zoneSubtitle)
                        .foregroundStyle(AppPalette.textSecondary)
                case .ready(let name, let byteString):
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .appTypography(.footnote)
                            .foregroundStyle(AppPalette.textSecondary)
                        SettingsModelFileInfoBlock(fileName: name, byteString: byteString)
                    }
                case .missingFile:
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(title) file not found")
                            .appTypography(.zoneSubtitle)
                            .foregroundStyle(.orange)
                        Text("Re-pick the file or forget this selection.")
                            .appTypography(.footnote)
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
                    .appTypography(.footnote)
                    .foregroundStyle(AppPalette.textSecondary)
            }
        case .succeeded(let summary, let raw):
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text(summary)
                        .appTypography(.footnote)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .imageScale(.medium)
                }
                .foregroundStyle(.green)
                DisclosureGroup(isExpanded: showTestResponse) {
                    Text(raw)
                        .appTypography(.footnote)
                        .foregroundStyle(AppPalette.textSecondary)
                        .textSelection(.enabled)
                        .padding(.top, 6)
                } label: {
                    Text("Show description")
                        .appTypography(.footnote)
                }
            }
        case .failed(let message):
            Label {
                Text(message)
                    .appTypography(.footnote)
            } icon: {
                Image(systemName: "xmark.circle.fill")
                    .imageScale(.medium)
            }
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

    private var visionTestPhotoLabel: some View {
        Label {
            Text(testJPEG == nil ? "Choose test photo" : "Replace test photo")
                .appTypography(.disclosureLabel)
        } icon: {
            Image(systemName: "photo")
        }
        .foregroundStyle(AppPalette.accent)
    }

    #if os(iOS)
    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        await applyTestJPEGData(data)
    }
    #else
    private func loadPhotoFromURL(_ url: URL) async {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return }
        await applyTestJPEGData(data)
    }
    #endif

    @MainActor
    private func applyTestJPEGData(_ data: Data) async {
        let jpeg = MediaImageEncoding.normalizedJPEG(from: data, maxDimension: 1600, quality: 0.82) ?? data
        testJPEG = jpeg
    }
}
