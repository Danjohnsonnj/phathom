import PhathomCore
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct AddNewTab: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedTab: Int

    @State private var captureMode: CaptureMode = .web
    @State private var title = ""
    @State private var urlString = ""
    @State private var noteMarkdown = ""
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var pickedImageJPEG: Data?
    @State private var pickedImagePreview: UIImage?
    @State private var saveError: String?
    @State private var saveSuccessMessage: String?

    enum CaptureMode: String, CaseIterable, Identifiable {
        case web
        case note
        case media

        var id: String { rawValue }
        var title: String {
            switch self {
            case .web: "Web"
            case .note: "Note"
            case .media: "Media"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $captureMode) {
                        ForEach(CaptureMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: captureMode) { _, _ in
                        photoPickerItem = nil
                        pickedImageJPEG = nil
                        pickedImagePreview = nil
                    }

                    TextField("Title", text: $title)

                    if captureMode == .web {
                        TextField("URL", text: $urlString)
                            .textContentType(.URL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                    } else if captureMode == .note {
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $noteMarkdown)
                                .frame(minHeight: 180)

                            if noteMarkdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("Write or paste Markdown...")
                                    .font(.body)
                                    .foregroundStyle(AppPalette.textTertiary)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 8)
                                    .allowsHitTesting(false)
                            }
                        }
                    } else {
                        PhotosPicker(selection: $photoPickerItem, matching: .images, photoLibrary: .shared()) {
                            Label(pickedImagePreview == nil ? "Choose photo" : "Replace photo", systemImage: "photo")
                        }
                        .onChange(of: photoPickerItem) { _, newItem in
                            Task { await loadPickedPhoto(newItem) }
                        }

                        if let preview = pickedImagePreview {
                            Image(uiImage: preview)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }

                Section {
                    Button("Cancel", role: .cancel) {
                        cancelAndDismiss()
                    }
                    .foregroundStyle(AppPalette.textSecondary)

                    Button("Save") {
                        saveItem()
                    }
                    .foregroundStyle(AppPalette.accent)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppPalette.background)
            .tint(AppPalette.accent)
            .foregroundStyle(AppPalette.textPrimary)
            .navigationTitle("Add new")
            .alert("Could not save", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "")
            }
            .alert("Saved", isPresented: Binding(
                get: { saveSuccessMessage != nil },
                set: { if !$0 { saveSuccessMessage = nil } }
            )) {
                Button("OK", role: .cancel) {
                    saveSuccessMessage = nil
                    selectedTab = 0
                }
            } message: {
                Text(saveSuccessMessage ?? "")
            }
        }
    }

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
        let jpeg = MediaImageEncoding.normalizedJPEG(from: data) ?? data
        pickedImageJPEG = jpeg
        pickedImagePreview = UIImage(data: jpeg)
    }

    private func cancelAndDismiss() {
        captureMode = .web
        title = ""
        urlString = ""
        noteMarkdown = ""
        photoPickerItem = nil
        pickedImageJPEG = nil
        pickedImagePreview = nil
        saveError = nil
        selectedTab = 0
    }

    private func saveItem() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = noteMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)

        switch captureMode {
        case .web:
            guard !trimmedURL.isEmpty,
                  let url = URL(string: trimmedURL),
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
            guard !trimmedNote.isEmpty else {
                saveError = "Please enter note content."
                return
            }

            let item = ContentItem(contentKind: .note)
            if trimmedTitle.isEmpty {
                let firstLine = trimmedNote.split(separator: "\n", omittingEmptySubsequences: false).first.map(String.init) ?? ""
                let plain = MarkdownNoteHelpers.plainTitleLine(from: firstLine)
                item.title = plain.isEmpty ? "Untitled note" : String(plain.prefix(80))
            } else {
                item.title = trimmedTitle
                item.titleUserSet = true
            }
            item.rawText = trimmedNote
            item.mediaDescription = String(trimmedNote.prefix(120))
            item.processingStatus = ProcessingStatus.embedding.rawValue
            item.processingDetail = "Preparing analysis…"
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
                title = ""
                urlString = ""
                noteMarkdown = ""
                photoPickerItem = nil
                pickedImageJPEG = nil
                pickedImagePreview = nil
                saveSuccessMessage = "Item added to your library."
                BackgroundPipeline.scheduleAll()
                BackgroundPipeline.scheduleForegroundDrain()
                return
            } catch {
                saveError = error.localizedDescription
                return
            }
        }

        do {
            try modelContext.save()
            LibraryContentChangeNotifier.postLibraryContentDidChange()
            title = ""
            urlString = ""
            noteMarkdown = ""
            photoPickerItem = nil
            pickedImageJPEG = nil
            pickedImagePreview = nil
            saveSuccessMessage = "Item added to your library."
            BackgroundPipeline.scheduleAll()
            BackgroundPipeline.scheduleForegroundDrain()
        } catch {
            saveError = error.localizedDescription
        }
    }
}
