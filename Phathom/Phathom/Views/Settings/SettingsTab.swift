import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsContent: View {
    @Query(filter: #Predicate<ContentItem> { $0.isArchived == true })
    private var archivedForBadge: [ContentItem]

    @State private var modelFiles: [URL] = []
    @State private var testPhase: TestPhase = .idle
    @State private var showFileImporter = false
    @State private var importerError: String?
    @State private var showTestResponse = false

    enum TestPhase {
        case idle
        case running
        case succeeded(summary: String, raw: String)
        case failed(message: String)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private let recommendedModels: [(name: String, url: URL)] = [
        ("Llama-3.1-8B-Instruct Q4_K_M (~4.5 GB)", URL(string: "https://huggingface.co/bartowski/Meta-Llama-3.1-8B-Instruct-GGUF")!),
        ("Llama-3.2-3B-Instruct Q4_K_M (~1.8 GB)", URL(string: "https://huggingface.co/bartowski/Meta-Llama-3.2-3B-Instruct-GGUF")!),
        ("Gemma-2-9B-Instruct Q4_K_M (~5.5 GB)", URL(string: "https://huggingface.co/bartowski/gemma-2-9b-it-GGUF")!),
    ]

    var body: some View {
        Form {
            Section {
                if let url = ModelManager.selectedModelURL {
                    LabeledContent("Selected model", value: url.lastPathComponent)
                    LabeledContent("Size", value: ModelManager.byteString(for: url))
                } else {
                    Text("No model selected")
                        .foregroundStyle(AppPalette.textSecondary)
                }

                Button("Choose from Documents folder") {
                    refreshModels()
                }

                Button("Import .gguf file…") {
                    showFileImporter = true
                }

                if !modelFiles.isEmpty {
                    ForEach(modelFiles, id: \.self) { url in
                        Button {
                            ModelManager.selectedModelURL = url
                            testPhase = .idle
                            showTestResponse = false
                        } label: {
                            HStack {
                                Text(url.lastPathComponent)
                                Spacer()
                            if ModelManager.selectedModelURL?.standardizedFileURL.path == url.standardizedFileURL.path {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(AppPalette.accent)
                                }
                            }
                        }
                    }
                }

                Button("Test selected model") {
                    runModelTest()
                }
                .disabled(isTestRunning || ModelManager.selectedModelURL == nil)

                switch testPhase {
                case .idle:
                    EmptyView()
                case .running:
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Running test inference…")
                            .font(.footnote)
                            .foregroundStyle(AppPalette.textSecondary)
                    }
                case .succeeded(let summary, let raw):
                    VStack(alignment: .leading, spacing: 8) {
                        Label(summary, systemImage: "checkmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(.green)
                        DisclosureGroup("Show response", isExpanded: $showTestResponse) {
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

                VStack(alignment: .leading, spacing: 8) {
                    Text("Add models")
                        .font(.subheadline.weight(.semibold))
                    Text("Download a GGUF, then use Files → On My iPhone → Phathom to place it in this app’s Documents folder, or import with the button above.")
                        .font(.footnote)
                        .foregroundStyle(AppPalette.textSecondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("On-device model")
            }

            Section("Library") {
                NavigationLink {
                    RecentlyDeletedView()
                } label: {
                    HStack {
                        Text("Recently Deleted")
                        Spacer()
                        if !archivedForBadge.isEmpty {
                            Text("\(archivedForBadge.count)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppPalette.textPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(AppPalette.surfaceNested)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            Section {
                ForEach(recommendedModels, id: \.name) { item in
                    Link(destination: item.url) {
                        Text(item.name)
                    }
                }
            } header: {
                Text("Recommended GGUFs")
            }

            Section("About") {
                LabeledContent("Version", value: appVersion)
                LabeledContent("Build", value: build)
                Text("Phathom keeps your library on this device only.")
                    .font(.footnote)
                    .foregroundStyle(AppPalette.textSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppPalette.background)
        .tint(AppPalette.accent)
        .foregroundStyle(AppPalette.textPrimary)
        .onAppear {
            ModelManager.validateSelection()
            refreshModels()
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [UTType(filenameExtension: "gguf") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let src = urls.first else { return }
                copyImportedGGUF(from: src)
            case .failure(let error):
                importerError = error.localizedDescription
            }
        }
        .alert("Import failed", isPresented: Binding(
            get: { importerError != nil },
            set: { if !$0 { importerError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importerError ?? "")
        }
    }

    private func refreshModels() {
        modelFiles = ModelManager.ggufFilesInDocuments()
    }

    private func copyImportedGGUF(from sourceURL: URL) {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            importerError = "Could not reach Documents directory."
            return
        }
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess { sourceURL.stopAccessingSecurityScopedResource() }
        }
        let dest = docs.appendingPathComponent(sourceURL.lastPathComponent)
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: sourceURL, to: dest)
            ModelManager.selectedModelURL = dest
            testPhase = .idle
            showTestResponse = false
            refreshModels()
        } catch {
            importerError = error.localizedDescription
        }
    }

    private func runModelTest() {
        guard let path = ModelManager.selectedModelURL?.path else { return }
        testPhase = .running
        showTestResponse = false
        Task {
            let analyzer = LlamaContentAnalyzer()
            do {
                try await analyzer.loadModel(path: path)
                let text = try await analyzer.runQuickTest()
                await analyzer.unloadModel()
                await MainActor.run {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    let response = trimmed.isEmpty ? "(empty response)" : trimmed
                    testPhase = .succeeded(
                        summary: "Model responded successfully.",
                        raw: response
                    )
                }
            } catch {
                await MainActor.run {
                    testPhase = .failed(message: error.localizedDescription)
                }
            }
        }
    }

    private var isTestRunning: Bool {
        if case .running = testPhase {
            return true
        }
        return false
    }
}

struct SettingsTab: View {
    var body: some View {
        NavigationStack {
            SettingsContent()
                .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsTab()
}
