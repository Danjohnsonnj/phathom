import PhathomCore
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SettingsContent: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    @State private var archivedCount: Int = 0
    @State private var selectionState: ModelManager.SelectionDisplayState = .noSelection
    @State private var testPhase: TestPhase = .idle
    @State private var showFileImporter = false
    @State private var importerError: String?
    @State private var showTestResponse = false
    @State private var changeModelExpanded: Bool = true
    @State private var showModelSelectionGuidance = false

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

    private var modelSelectionGuidance: String {
        "Model files are used for summarization and tagging in the background. "
            + "Download a `.gguf` file from Hugging Face or another model vendor and save it to a folder on your device in the Files app. "
            + "Phathom will automatically detect and use this model for future tasks."
            + "\n\n`Select model from files...` creates a security bookmark and reads it in place without duplicating the file into the app."
    }

    private var canRunTest: Bool {
        if case .ready = selectionState { return true }
        return false
    }

    var body: some View {
        Form {
            Section {
                modelStatusRows

                Button("Test model") {
                    runModelTest()
                }
                .disabled(isTestRunning || !canRunTest)

                testPhaseRows

                DisclosureGroup("Change model", isExpanded: $changeModelExpanded) {
                    Button("Select model from Files…") {
                        showFileImporter = true
                    }

                    if ModelManager.hasBookmark {
                        Button("Forget selection", role: .destructive) {
                            ModelManager.clearSelection()
                            testPhase = .idle
                            showTestResponse = false
                            refreshSelectionState()
                        }
                    }

                    Button {
                        showModelSelectionGuidance = true
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Image(systemName: "info.circle")
                            Text("About model files")
                        }
                        .font(.footnote)
                        .foregroundStyle(AppPalette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("AI model")
            }

            Section("Library") {
                NavigationLink {
                    RecentlyDeletedView()
                } label: {
                    HStack {
                        Text("Recently Deleted")
                        Spacer()
                        if archivedCount > 0 {
                            Text("\(archivedCount)")
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
            refreshSelectionState()
            refreshArchivedCount()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                ModelManager.validateSelection()
                refreshSelectionState()
                refreshArchivedCount()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .phathomDidArchiveItem)) { _ in
            refreshArchivedCount()
        }
        .onReceive(NotificationCenter.default.publisher(for: .phathomArchivedItemsDidChange)) { _ in
            refreshArchivedCount()
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [UTType(filenameExtension: "gguf") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let src = urls.first else { return }
                do {
                    try ModelManager.setSelection(from: src)
                    testPhase = .idle
                    showTestResponse = false
                    refreshSelectionState()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } catch {
                    importerError = error.localizedDescription
                }
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
        .sheet(isPresented: $showModelSelectionGuidance) {
            NavigationStack {
                ScrollView {
                    Text(modelSelectionGuidance)
                        .font(.body)
                        .foregroundStyle(AppPalette.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .scrollContentBackground(.hidden)
                .background(AppPalette.background)
                .navigationTitle("Model files")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            showModelSelectionGuidance = false
                        }
                    }
                }
            }
            .tint(AppPalette.accent)
        }
    }

    @ViewBuilder
    private var modelStatusRows: some View {
        switch selectionState {
        case .noSelection:
            Text("No model selected.")
                .foregroundStyle(AppPalette.textSecondary)
        case .ready(let name, let byteString):
            LabeledContent("Selected model", value: name)
            LabeledContent("Size", value: byteString)
            Text("Summaries and tagging run with this file when the app is in the background.")
                .font(.footnote)
                .foregroundStyle(AppPalette.textSecondary)
                .padding(.top, 4)
        case .missingFile:
            Text("Model file not found")
                .foregroundStyle(.orange)
            Text("The file may have moved or been deleted. Choose a new model or forget this selection.")
                .font(.footnote)
                .foregroundStyle(AppPalette.textSecondary)
        }
    }

    @ViewBuilder
    private var testPhaseRows: some View {
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
    }

    private func refreshArchivedCount() {
        let fd = FetchDescriptor<ContentItem>(
            predicate: #Predicate<ContentItem> { $0.isArchived == true }
        )
        archivedCount = (try? modelContext.fetchCount(fd)) ?? 0
    }

    private func refreshSelectionState() {
        ModelManager.validateSelection()
        let next = ModelManager.selectionDisplayState()
        selectionState = next
        switch next {
        case .ready:
            changeModelExpanded = false
        case .noSelection, .missingFile:
            changeModelExpanded = true
        }
    }

    private func runModelTest() {
        testPhase = .running
        showTestResponse = false
        Task {
            do {
                try await SharedLlamaInference.shared.ensureLoaded()
                let text = try await SharedLlamaInference.shared.runQuickTest()
                await SharedLlamaInference.shared.unload()
                await MainActor.run {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    let response = trimmed.isEmpty ? "(empty response)" : trimmed
                    testPhase = .succeeded(
                        summary: "Model responded successfully.",
                        raw: response
                    )
                }
            } catch {
                await SharedLlamaInference.shared.unload()
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
