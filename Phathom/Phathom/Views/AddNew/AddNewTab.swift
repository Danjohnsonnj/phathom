import PhathomCore
import SwiftData
import SwiftUI
#if os(iOS)
import PhotosUI
import UIKit
#elseif os(macOS)
import AppKit
#endif
import UniformTypeIdentifiers

struct AddNewTab: View {
    private enum Layout {
        static let insetWellCornerRadius: CGFloat = 11
        static let insetWellPadding: CGFloat = 14
        static let iconWellSize: CGFloat = 28
        static let noteEditorMinHeight: CGFloat = 180
        static let photoPreviewMaxHeight: CGFloat = 220
        static let photoPreviewCornerRadius: CGFloat = 8
        static let modeBarInnerInset: CGFloat = 4
    }

    @Environment(\.modelContext) private var modelContext
    var onNavigateToLibrary: () -> Void

    @State private var captureMode: CaptureMode = .web
    @State private var title = ""
    @State private var urlString = ""
    @State private var noteMarkdown = ""
    #if os(iOS)
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var pickedImagePreview: UIImage?
    #else
    @State private var showImageImporter = false
    @State private var pickedImagePreview: NSImage?
    #endif
    @State private var pickedImageJPEG: Data?
    @State private var saveError: String?

    enum CaptureMode: String, CaseIterable, Identifiable {
        case web
        case note
        case media

        var id: String { rawValue }
        var title: String {
            switch self {
            case .web: "Web"
            case .note: "Note"
            case .media: "Photo"
            }
        }

        var segmentedIcon: String {
            switch self {
            case .web: "link"
            case .note: "doc.text"
            case .media: "photo"
            }
        }

        var accentLabelUppercase: String {
            switch self {
            case .web: "PASTE URL"
            case .note: "WRITE NOTE"
            case .media: "CHOOSE PHOTO"
            }
        }

        var modeHeaderIcon: String {
            segmentedIcon
        }
    }

    private var trimmedURL: String {
        urlString.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedNote: String {
        noteMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Disables Save when required input for the mode is empty (still allow tap path for malformed URL validation).
    private var canSave: Bool {
        switch captureMode {
        case .web: !trimmedURL.isEmpty
        case .note: !trimmedNote.isEmpty
        case .media: pickedImageJPEG != nil && !(pickedImageJPEG?.isEmpty ?? true)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.sectionVerticalGap) {
                    EditorialScreenTitle(title: "Save", bottomSpacing: 0)

                    captureCard

                    saveToLibraryButton
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, 12)
                .padding(.bottom, AppSpacing.sectionVerticalGap)
            }
            .scrollIndicators(.hidden)
            .contentMargins(.bottom, AppSpacing.tabBarScrollInset, for: .scrollContent)
            .foregroundStyle(AppPalette.textPrimary)
            .background(AppPalette.background)
            .safeAreaInset(edge: .bottom, spacing: Layout.modeBarInnerInset * 2) {
                captureModeBar
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.bottom, Layout.modeBarInnerInset)
            }
            .tint(AppPalette.accent)
            .phathomHideNavigationBar()
            .onChange(of: captureMode) { _, _ in
                #if os(iOS)
                photoPickerItem = nil
                #endif
                pickedImageJPEG = nil
                pickedImagePreview = nil
            }
            .alert("Could not save", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "")
            }
        }
    }

    private var captureCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppPalette.accent.opacity(0.22))
                    Image(systemName: captureMode.modeHeaderIcon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppPalette.accent)
                }
                .frame(width: Layout.iconWellSize, height: Layout.iconWellSize)

                Text(captureMode.accentLabelUppercase)
                    .appTypography(.addNewAccentLabel)
                    .foregroundStyle(AppPalette.accent)
            }

            Group {
                switch captureMode {
                case .web:
                    urlInsetWell
                    optionalTitleUnderline
                case .note:
                    optionalTitleUnderline
                    noteEditorInsetWell
                case .media:
                    photoInsetWell
                    optionalTitleUnderline
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius, style: .continuous))
    }

    private var urlInsetWell: some View {
        TextField("https://...", text: $urlString)
            .appTypography(.body)
            .foregroundStyle(AppPalette.textPrimary)
            .textContentType(.URL)
            .phathomURLKeyboard()
            .phathomAutocapitalizationNever()
            .autocorrectionDisabled()
            .padding(Layout.insetWellPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppPalette.surfaceNested)
            .clipShape(RoundedRectangle(cornerRadius: Layout.insetWellCornerRadius, style: .continuous))
    }

    private var optionalTitleUnderline: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Custom title (optional)", text: $title)
                .appTypography(.body)
                .foregroundStyle(AppPalette.textPrimary)
                .textFieldStyle(.plain)
            Divider()
                .overlay(AppPalette.textTertiary.opacity(0.45))
        }
    }

    private var noteEditorInsetWell: some View {
        TextEditor(text: $noteMarkdown)
            .appTypography(.body)
            .frame(minHeight: Layout.noteEditorMinHeight)
            .scrollContentBackground(.hidden)
            .foregroundStyle(AppPalette.textPrimary)
            .padding(.horizontal, Layout.insetWellPadding - 4)
            .padding(.vertical, Layout.insetWellPadding - 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppPalette.surfaceNested)
            .clipShape(RoundedRectangle(cornerRadius: Layout.insetWellCornerRadius, style: .continuous))
    }

    private var photoInsetWell: some View {
        VStack(alignment: .leading, spacing: 12) {
            #if os(iOS)
            PhotosPicker(selection: $photoPickerItem, matching: .images, photoLibrary: .shared()) {
                photoPickerLabel
            }
            .buttonStyle(.plain)
            .onChange(of: photoPickerItem) { _, newItem in
                Task { await loadPickedPhoto(newItem) }
            }
            #else
            Button {
                showImageImporter = true
            } label: {
                photoPickerLabel
            }
            .buttonStyle(.plain)
            .fileImporter(
                isPresented: $showImageImporter,
                allowedContentTypes: [.jpeg, .png, .heic, .image],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    Task { await loadPickedPhotoFromURL(url) }
                case .failure:
                    pickedImageJPEG = nil
                    pickedImagePreview = nil
                }
            }
            #endif

            if let preview = pickedImagePreview {
                #if os(iOS)
                Image(uiImage: preview)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: Layout.photoPreviewMaxHeight)
                    .clipShape(RoundedRectangle(cornerRadius: Layout.photoPreviewCornerRadius, style: .continuous))
                    .frame(maxWidth: .infinity)
                #else
                Image(nsImage: preview)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: Layout.photoPreviewMaxHeight)
                    .clipShape(RoundedRectangle(cornerRadius: Layout.photoPreviewCornerRadius, style: .continuous))
                    .frame(maxWidth: .infinity)
                #endif
            }
        }
        .padding(Layout.insetWellPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.surfaceNested)
        .clipShape(RoundedRectangle(cornerRadius: Layout.insetWellCornerRadius, style: .continuous))
    }

    private var photoPickerLabel: some View {
        HStack {
            Label {
                Text(pickedImagePreview == nil ? "Choose photo" : "Replace photo")
                    .appTypography(.body)
                    .foregroundStyle(
                        pickedImagePreview == nil
                            ? AppPalette.textSecondary.opacity(0.38)
                            : AppPalette.textPrimary
                    )
            } icon: {
                Image(systemName: "photo")
                    .foregroundStyle(AppPalette.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppPalette.textTertiary)
        }
        .padding(Layout.insetWellPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    #if os(iOS)
    @MainActor
    private func loadPickedPhoto(_ item: PhotosPickerItem?) async {
        guard let item else {
            pickedImageJPEG = nil
            pickedImagePreview = nil
            return
        }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            pickedImageJPEG = nil
            pickedImagePreview = nil
            return
        }
        applyPickedImageData(data)
    }
    #else
    @MainActor
    private func loadPickedPhotoFromURL(_ url: URL) async {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            pickedImageJPEG = nil
            pickedImagePreview = nil
            return
        }
        applyPickedImageData(data)
    }
    #endif

    @MainActor
    private func applyPickedImageData(_ data: Data) {
        let jpeg = MediaImageEncoding.normalizedJPEGForLibraryStorage(from: data) ?? data
        pickedImageJPEG = jpeg
        #if os(iOS)
        pickedImagePreview = UIImage(data: jpeg)
        #else
        pickedImagePreview = NSImage(data: jpeg)
        #endif
    }

    private var saveToLibraryButton: some View {
        Button(action: saveItem) {
            HStack(spacing: 8) {
                Text("Save to Library")
                    .appTypography(.bodySemibold)
                    .phathomCapsuleCTALabel()
                Image(systemName: "arrow.right")
                    .font(.system(size: 17, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: AppSpacing.capsuleCTAHeight)
            .foregroundStyle(canSave ? AppPalette.textPrimary : AppPalette.textSecondary)
            .background(canSave ? AppPalette.accent : AppPalette.surfaceNested)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .accessibilityHint("Adds the item and opens your Library tab.")
        .opacity(canSave ? 1 : 0.85)
    }

    private var captureModeBar: some View {
        HStack(spacing: 0) {
            ForEach(CaptureMode.allCases) { mode in
                Button {
                    captureMode = mode
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: mode.segmentedIcon)
                            .font(.system(size: 15, weight: .medium))
                        Text(mode.title)
                            .appTypography(.subsectionHeader)
                            .phathomToolbarTextLabel()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(captureMode == mode ? AppPalette.textPrimary : AppPalette.textSecondary)
                    .background {
                        if captureMode == mode {
                            RoundedRectangle(
                                cornerRadius: AppSpacing.modePillOuterRadius - Layout.modeBarInnerInset,
                                style: .continuous
                            )
                            .fill(AppPalette.surfaceNested)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(mode.title)
                .accessibilityAddTraits(captureMode == mode ? .isSelected : [])
            }
        }
        .padding(Layout.modeBarInnerInset)
        .frame(maxWidth: .infinity)
        .frame(height: AppSpacing.modePillOuterRadius * 2)
        .background(AppPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.modePillOuterRadius, style: .continuous))
    }

    private func resetFormAfterSave() {
        captureMode = .web
        title = ""
        urlString = ""
        noteMarkdown = ""
        #if os(iOS)
        photoPickerItem = nil
        #endif
        pickedImageJPEG = nil
        pickedImagePreview = nil
        saveError = nil
    }

    private func saveItem() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlTrim = trimmedURL
        let noteTrim = trimmedNote

        switch captureMode {
        case .web:
            guard !urlTrim.isEmpty,
                  let url = URL(string: urlTrim),
                  url.scheme != nil else {
                saveError = "Please enter a valid URL for a web capture."
                return
            }

            let item = ContentItem(contentKind: .web, originalURL: url)
            item.title = trimmedTitle.isEmpty ? nil : trimmedTitle
            item.titleUserSet = !trimmedTitle.isEmpty
            item.processingStatus = ProcessingStatus.pending.rawValue
            item.processingDetail = "Queued for capture"
            modelContext.insert(item)

        case .note:
            guard !noteTrim.isEmpty else {
                saveError = "Please enter note content."
                return
            }

            let item = ContentItem(contentKind: .note)
            if trimmedTitle.isEmpty {
                let firstLine = noteTrim.split(separator: "\n", omittingEmptySubsequences: false).first.map(String.init) ?? ""
                let plain = MarkdownNoteHelpers.plainTitleLine(from: firstLine)
                item.title = plain.isEmpty ? "Untitled note" : String(plain.prefix(80))
            } else {
                item.title = trimmedTitle
                item.titleUserSet = true
            }
            item.rawText = noteTrim
            item.mediaDescription = String(noteTrim.prefix(120))
            item.processingStatus = ProcessingStatus.embedding.rawValue
            item.processingDetail = ProcessingStatusPresentation.embeddingProcessingDetail
            modelContext.insert(item)

        case .media:
            guard let jpeg = pickedImageJPEG, !jpeg.isEmpty else {
                saveError = "Please choose a photo."
                return
            }
            do {
                try ShareCapture.insertMediaItem(
                    context: modelContext,
                    imageJPEGData: jpeg,
                    title: trimmedTitle.isEmpty ? nil : trimmedTitle
                )
                BackgroundPipeline.scheduleAll()
                BackgroundPipeline.scheduleForegroundDrain()
                resetFormAfterSave()
                onNavigateToLibrary()
                return
            } catch {
                saveError = error.localizedDescription
                return
            }
        }

        do {
            try modelContext.save()
            LibraryContentChangeNotifier.postLibraryContentDidChange()
            BackgroundPipeline.scheduleAll()
            BackgroundPipeline.scheduleForegroundDrain()
            resetFormAfterSave()
            onNavigateToLibrary()
        } catch {
            saveError = error.localizedDescription
        }
    }
}

#Preview {
    AddNewTab(onNavigateToLibrary: {})
        .modelContainer(PreviewModel.makeContainer())
}
