import SwiftData
import SwiftUI

struct AddNewTab: View {
    @Environment(\.modelContext) private var modelContext

    @State private var title = ""
    @State private var urlString = ""
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                    TextField("URL (optional)", text: $urlString)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                }

                Section {
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
        }
    }

    private func saveItem() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        if let url = URL(string: trimmedURL), !trimmedURL.isEmpty, url.scheme != nil {
            let item = ContentItem(contentKind: .web, originalURL: url)
            item.title = trimmedTitle.isEmpty ? (url.host ?? trimmedURL) : trimmedTitle
            item.processingStatus = ProcessingStatus.pending.rawValue
            item.processingDetail = "Queued for capture"
            modelContext.insert(item)
        } else {
            let item = ContentItem(contentKind: .note)
            item.title = trimmedTitle.isEmpty ? "Untitled note" : trimmedTitle
            item.rawText = trimmedTitle.isEmpty ? "Empty note" : trimmedTitle
            item.processingStatus = ProcessingStatus.embedding.rawValue
            item.processingDetail = "Preparing analysis…"
            modelContext.insert(item)
        }

        do {
            try modelContext.save()
            title = ""
            urlString = ""
            BackgroundPipeline.scheduleAll()
        } catch {
            saveError = error.localizedDescription
        }
    }
}
