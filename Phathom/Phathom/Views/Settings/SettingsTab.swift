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
    @State private var requestedImporter: ImportPickerMode?
    @State private var callbackImporter: ImportPickerMode?
    @State private var importerError: String?
    @State private var showTestResponse = false
    @State private var changeModelExpanded: Bool = true
    @State private var showModelSelectionGuidance = false
    @State private var showBackupExporter = false
    @State private var backupDocument = BackupJSONDocument()
    @State private var backupDefaultFilename = "phathom-library-backup.json"
    @State private var pendingImportData: Data?
    @State private var pendingImportPreview: LibraryBackupService.ImportPreview?
    @State private var showImportConflictDialog = false
    @State private var importSuccessMessage: String?
    @State private var importErrorTitle = "Import failed"
    @State private var importErrorDetails: String?
    @State private var showImportErrorSheet = false
    @State private var backupBusy = false

    enum TestPhase {
        case idle
        case running
        case succeeded(summary: String, raw: String)
        case failed(message: String)
    }

    enum ImportPickerMode: String {
        case model
        case backup
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

    private var importerBinding: Binding<Bool> {
        Binding(
            get: { requestedImporter != nil },
            set: { isPresented in
                if !isPresented {
                    requestedImporter = nil
                }
            }
        )
    }

    private var importerAllowedTypes: [UTType] {
        switch requestedImporter {
        case .model:
            return [UTType(filenameExtension: "gguf") ?? .data, .data]
        case .backup:
            return [.json]
        case nil:
            return [.data]
        }
    }

    var body: some View {
        configuredForm
    }

    private var configuredForm: some View {
        baseConfiguredForm
            .fileImporter(
                isPresented: importerBinding,
                allowedContentTypes: importerAllowedTypes,
                allowsMultipleSelection: false
            ) { result in
                let mode = callbackImporter
                defer { callbackImporter = nil }
                switch mode {
                case .model:
                    handleModelImportSelection(result)
                case .backup:
                    handleBackupImportSelection(result)
                case nil:
                    return
                }
            }
            .fileExporter(
                isPresented: $showBackupExporter,
                document: backupDocument,
                contentType: .json,
                defaultFilename: backupDefaultFilename
            ) { result in
                handleBackupExportResult(result)
            }
            .confirmationDialog(
                "Import options",
                isPresented: $showImportConflictDialog,
                presenting: pendingImportPreview
            ) { preview in
                Button("Replace existing items", role: .destructive) {
                    commitImport(policy: .replace, preview: preview)
                }
                Button("Merge with existing and archived items") {
                    commitImport(policy: .merge, preview: preview)
                }
                Button("Cancel", role: .cancel) {
                    clearPendingImport()
                }
            } message: { preview in
                Text("Import contains \(preview.itemCount) items. Existing items found in library.")
            }
            .alert("Process complete", isPresented: Binding(
                get: { importSuccessMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        importSuccessMessage = nil
                    }
                }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importSuccessMessage ?? "")
            }
            .alert(importErrorTitle, isPresented: Binding(
                get: { importErrorDetails != nil },
                set: { isPresented in
                    if !isPresented {
                        importErrorDetails = nil
                    }
                }
            )) {
                Button("View details") { showImportErrorSheet = true }
                Button("OK", role: .cancel) {}
            } message: {
                Text("Operation failed. View details for debugging info.")
            }
            .sheet(isPresented: $showImportErrorSheet) {
                importErrorDetailsSheet
            }
    }

    private var baseConfiguredForm: some View {
        settingsForm
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
            .onChange(of: requestedImporter) { _, mode in
                if mode != nil {
                    callbackImporter = mode
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
                modelFileInfoSheet
            }
    }

    private var settingsForm: some View {
        Form {
            modelSection
            librarySection
            backupSection
            aboutSection
        }
    }

    private var modelSection: some View {
        Section {
            modelStatusRows
            Button("Test model") {
                runModelTest()
            }
            .disabled(isTestRunning || !canRunTest)
            testPhaseRows
            DisclosureGroup("Change model", isExpanded: $changeModelExpanded) {
                Button("Select model from Files…") {
                    requestedImporter = .model
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
    }

    private var librarySection: some View {
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
    }

    private var backupSection: some View {
        Section {
            Button("Export Library Backup") {
                exportLibraryBackup()
            }
            .disabled(backupBusy)
            Button("Import Library Backup") {
                requestedImporter = .backup
            }
            .disabled(backupBusy)
        } header: {
            Text("Backup")
        } footer: {
            Text("Exports active library items only. Archived items are excluded.")
                .font(.footnote)
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: appVersion)
            LabeledContent("Build", value: build)
            Text("Phathom keeps your library on this device only.")
                .font(.footnote)
                .foregroundStyle(AppPalette.textSecondary)
        }
    }

    private var modelFileInfoSheet: some View {
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

    private var importErrorDetailsSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                ScrollView {
                    Text(importErrorDetails ?? "")
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Button("Copy details to clipboard") {
                    UIPasteboard.general.string = importErrorDetails ?? ""
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Import error details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showImportErrorSheet = false }
                }
            }
        }
        .tint(AppPalette.accent)
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
                let text = try await SharedLlamaInference.shared.withSession { session in
                    try await session.runQuickTest()
                }
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

    private func exportLibraryBackup() {
        backupBusy = true
        do {
            let buildString = "\(appVersion) (\(build))"
            let data = try LibraryBackupService.exportData(
                from: modelContext,
                appBuild: buildString
            )
            backupDocument = BackupJSONDocument(data: data)
            let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            backupDefaultFilename = "phathom-library-backup-\(stamp).json"
            showBackupExporter = true
        } catch {
            backupBusy = false
            presentImportFailure(
                title: "Export failed",
                details: makeDiagnostics(for: error)
            )
        }
    }

    private func handleBackupImportSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let src = urls.first else {
                return
            }
            backupBusy = true
            let access = src.startAccessingSecurityScopedResource()
            defer {
                if access {
                    src.stopAccessingSecurityScopedResource()
                }
            }
            do {
                let data = try Data(contentsOf: src)
                let preview = try LibraryBackupService.previewImport(data: data)
                pendingImportData = data
                pendingImportPreview = preview
                let hasExistingItems = ((try? modelContext.fetchCount(FetchDescriptor<ContentItem>())) ?? 0) > 0
                if hasExistingItems {
                    showImportConflictDialog = true
                    backupBusy = false
                } else {
                    commitImport(policy: .merge, preview: preview)
                }
            } catch {
                backupBusy = false
                presentImportFailure(
                    title: "Import failed",
                    details: makeDiagnostics(for: error)
                )
            }
        case .failure(let error):
            backupBusy = false
            presentImportFailure(
                title: "Import failed",
                details: makeDiagnostics(for: error)
            )
        }
    }

    private func handleModelImportSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let src = urls.first else {
                return
            }
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

    private func handleBackupExportResult(_ result: Result<URL, Error>) {
        backupBusy = false
        switch result {
        case .success:
            importSuccessMessage = "Backup exported successfully."
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .failure(let error):
            presentImportFailure(
                title: "Export failed",
                details: makeDiagnostics(for: error)
            )
        }
    }

    private func commitImport(
        policy: LibraryBackupService.ImportPolicy,
        preview: LibraryBackupService.ImportPreview
    ) {
        guard let data = pendingImportData else {
            clearPendingImport()
            backupBusy = false
            return
        }
        do {
            let result = try LibraryBackupService.importData(
                data,
                policy: policy,
                into: modelContext
            )
            refreshArchivedCount()
            let policyLabel = policy == .replace ? "replaced" : "merged"
            importSuccessMessage =
                "Import \(policyLabel): \(result.importedCount) items imported, \(result.skippedDuplicateCount) duplicates skipped (of \(preview.itemCount) in file)."
            clearPendingImport()
            backupBusy = false
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } catch {
            backupBusy = false
            clearPendingImport()
            presentImportFailure(
                title: "Import failed",
                details: makeDiagnostics(for: error)
            )
        }
    }

    private func clearPendingImport() {
        pendingImportData = nil
        pendingImportPreview = nil
    }

    private func presentImportFailure(title: String, details: String) {
        importErrorTitle = title
        importErrorDetails = details
    }

    private func makeDiagnostics(for error: Error) -> String {
        if let backupError = error as? LibraryBackupService.BackupError {
            return [
                "title=\(backupError.localizedDescription)",
                backupError.diagnosticText,
            ].joined(separator: "\n")
        }
        return [
            "title=\(error.localizedDescription)",
            "code=unexpected_error",
            "type=\(String(describing: type(of: error)))",
        ].joined(separator: "\n")
    }

}

private struct BackupJSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let payload = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        data = payload
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
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
