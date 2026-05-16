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
    @State private var taggingSelectionState: ModelManager.SelectionDisplayState = .noSelection
    @State private var primaryTestPhase: ModelTestPhase = .idle
    @State private var taggingTestPhase: ModelTestPhase = .idle
    @State private var requestedImporter: ImportPickerMode?
    @State private var callbackImporter: ImportPickerMode?
    @State private var importerError: String?
    @State private var showPrimaryTestResponse = false
    @State private var showTaggingTestResponse = false
    @State private var changePrimaryModelExpanded: Bool = true
    @State private var changeTaggingModelExpanded: Bool = false
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

    private enum ModelTestPhase {
        case idle
        case running
        case succeeded(summary: String, raw: String, subtitle: String?)
        case failed(message: String)
    }

    enum ImportPickerMode: String {
        case primaryModel
        case taggingModel
        case backup
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var modelSelectionGuidance: String {
        """
        Download `.gguf` weights from Hugging Face or another vendor and save them under **On My iPhone** (or another local folder) in the Files app.

        **Primary model** powers summaries, extracts, Library “Dive deeper,” related-item ranking, and Settings tests for the primary path.

        **Tagging model** (optional) is used only when generating tags during ingest and when you tap **Regenerate tags**. If it is missing or fails to load, tagging falls back to the primary model.

        Choosing a file creates a security-scoped bookmark—Phathom reads the weights in place without copying them into the app sandbox.
        """
    }

    private var canRunPrimaryTest: Bool {
        if case .ready = selectionState { return true }
        return false
    }

    /// Tagging test uses `taggingPreferred` routing and can load tagging-only weights when the primary file is unset but the tagging file is readable.
    private var canRunTaggingTest: Bool {
        if case .ready = selectionState { return true }
        if case .ready = taggingSelectionState { return true }
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
        case .primaryModel, .taggingModel:
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
                case .primaryModel:
                    handlePrimaryModelImportSelection(result)
                case .taggingModel:
                    handleTaggingModelImportSelection(result)
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
                    ModelManager.validateTaggingSelection()
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
            Text("Primary model")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppPalette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 4, trailing: 0))
                .listRowBackground(Color.clear)

            primaryModelStatusRows

            Button("Test primary model") {
                runPrimaryModelTest()
            }
            .disabled(isPrimaryTestRunning || !canRunPrimaryTest)

            primaryTestPhaseRows

            DisclosureGroup("Change primary model", isExpanded: $changePrimaryModelExpanded) {
                Button("Select primary model from Files…") {
                    requestedImporter = .primaryModel
                }
                if ModelManager.hasBookmark {
                    Button("Forget primary model", role: .destructive) {
                        ModelManager.clearSelection()
                        primaryTestPhase = .idle
                        showPrimaryTestResponse = false
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

            Text("Tagging model (optional)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppPalette.textPrimary)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 4, trailing: 0))
                .listRowBackground(Color.clear)

            taggingModelStatusRows

            Button("Test tagging model path") {
                runTaggingModelTest()
            }
            .disabled(isTaggingTestRunning || !canRunTaggingTest)

            taggingTestPhaseRows

            DisclosureGroup("Change tagging model", isExpanded: $changeTaggingModelExpanded) {
                Button("Select tagging model from Files…") {
                    requestedImporter = .taggingModel
                }
                if ModelManager.hasTaggingBookmark {
                    Button("Forget tagging model", role: .destructive) {
                        ModelManager.clearTaggingSelection()
                        taggingTestPhase = .idle
                        showTaggingTestResponse = false
                        refreshSelectionState()
                    }
                }
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
    private var primaryModelStatusRows: some View {
        switch selectionState {
        case .noSelection:
            Text("No primary model selected.")
                .foregroundStyle(AppPalette.textSecondary)
        case .ready(let name, let byteString):
            LabeledContent("Selected file", value: name)
            LabeledContent("Size", value: byteString)
            Text("Used for summaries, extracts, Library semantic search, related items, and as fallback for tagging.")
                .font(.footnote)
                .foregroundStyle(AppPalette.textSecondary)
                .padding(.top, 4)
        case .missingFile:
            Text("Primary model file not found")
                .foregroundStyle(.orange)
            Text("The file may have moved or been deleted. Choose a new primary model or forget this selection.")
                .font(.footnote)
                .foregroundStyle(AppPalette.textSecondary)
        }
    }

    @ViewBuilder
    private var taggingModelStatusRows: some View {
        switch taggingSelectionState {
        case .noSelection:
            Text("No optional tagging model — tags use the primary model.")
                .foregroundStyle(AppPalette.textSecondary)
        case .ready(let name, let byteString):
            LabeledContent("Selected file", value: name)
            LabeledContent("Size", value: byteString)
            Text("Used only when automatically tagging items or tapping Regenerate tags. Falls back to primary if this file is unavailable.")
                .font(.footnote)
                .foregroundStyle(AppPalette.textSecondary)
                .padding(.top, 4)
        case .missingFile:
            Text("Tagging model file not found")
                .foregroundStyle(.orange)
            Text("Tagging will use the primary model until you pick a new tagging file or forget this selection.")
                .font(.footnote)
                .foregroundStyle(AppPalette.textSecondary)
        }
    }

    @ViewBuilder
    private var primaryTestPhaseRows: some View {
        modelTestPhaseRows(phase: primaryTestPhase, showResponse: $showPrimaryTestResponse)
    }

    @ViewBuilder
    private var taggingTestPhaseRows: some View {
        modelTestPhaseRows(phase: taggingTestPhase, showResponse: $showTaggingTestResponse)
    }

    @ViewBuilder
    private func modelTestPhaseRows(
        phase: ModelTestPhase,
        showResponse: Binding<Bool>
    ) -> some View {
        switch phase {
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
        case .succeeded(let summary, let raw, let subtitle):
            VStack(alignment: .leading, spacing: 8) {
                Label(summary, systemImage: "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.green)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(AppPalette.textSecondary)
                }
                DisclosureGroup("Show response", isExpanded: showResponse) {
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
        ModelManager.validateTaggingSelection()
        let next = ModelManager.selectionDisplayState()
        selectionState = next
        taggingSelectionState = ModelManager.taggingSelectionDisplayState()
        switch next {
        case .ready:
            changePrimaryModelExpanded = false
        case .noSelection, .missingFile:
            changePrimaryModelExpanded = true
        }
        switch taggingSelectionState {
        case .ready:
            changeTaggingModelExpanded = false
        case .noSelection:
            changeTaggingModelExpanded = false
        case .missingFile:
            changeTaggingModelExpanded = true
        }
    }

    private func runPrimaryModelTest() {
        primaryTestPhase = .running
        showPrimaryTestResponse = false
        Task {
            do {
                let text = try await SharedLlamaInference.shared.withSession(role: .primary) { session in
                    try await session.runQuickTest()
                }
                await MainActor.run {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    let response = trimmed.isEmpty ? "(empty response)" : trimmed
                    primaryTestPhase = .succeeded(
                        summary: "Primary model responded successfully.",
                        raw: response,
                        subtitle: nil
                    )
                }
            } catch {
                await MainActor.run {
                    primaryTestPhase = .failed(message: error.localizedDescription)
                }
            }
        }
    }

    private func runTaggingModelTest() {
        taggingTestPhase = .running
        showTaggingTestResponse = false
        Task {
            do {
                let text = try await SharedLlamaInference.shared.withSession(role: .taggingPreferred) { session in
                    try await session.runQuickTest()
                }
                let usedFallback = await SharedLlamaInference.shared.lastTaggingPreferredUsedPrimaryFallback
                await MainActor.run {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    let response = trimmed.isEmpty ? "(empty response)" : trimmed
                    let subtitle: String? = usedFallback
                        ? "Used primary model (tagging file missing or failed to load)."
                        : nil
                    taggingTestPhase = .succeeded(
                        summary: "Tagging path responded successfully.",
                        raw: response,
                        subtitle: subtitle
                    )
                }
            } catch {
                await MainActor.run {
                    taggingTestPhase = .failed(message: error.localizedDescription)
                }
            }
        }
    }

    private var isPrimaryTestRunning: Bool {
        if case .running = primaryTestPhase {
            return true
        }
        return false
    }

    private var isTaggingTestRunning: Bool {
        if case .running = taggingTestPhase {
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

    private func handlePrimaryModelImportSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let src = urls.first else {
                return
            }
            do {
                try ModelManager.setSelection(from: src)
                primaryTestPhase = .idle
                showPrimaryTestResponse = false
                refreshSelectionState()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } catch {
                importerError = error.localizedDescription
            }
        case .failure(let error):
            importerError = error.localizedDescription
        }
    }

    private func handleTaggingModelImportSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let src = urls.first else {
                return
            }
            do {
                try ModelManager.setTaggingSelection(from: src)
                taggingTestPhase = .idle
                showTaggingTestResponse = false
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

}




