import PhathomCore
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SettingsContent: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    @State private var archivedCount: Int = 0
    @State private var activeWebProcessingQueueCount: Int = 0
    @State private var selectionState: ModelManager.SelectionDisplayState = .noSelection
    @State private var taggingSelectionState: ModelManager.SelectionDisplayState = .noSelection
    @State private var visionTextSelectionState: ModelManager.SelectionDisplayState = .noSelection
    @State private var visionMmprojSelectionState: ModelManager.SelectionDisplayState = .noSelection
    @State private var primaryTestPhase: ModelTestPhase = .idle
    @State private var taggingTestPhase: ModelTestPhase = .idle
    @State private var visionTestPhase: VisionModelSettingsSection.TestPhase = .idle
    @State private var requestedImporter: ImportPickerMode?
    @State private var callbackImporter: ImportPickerMode?
    @State private var importerError: String?
    @State private var showPrimaryTestResponse = false
    @State private var showTaggingTestResponse = false
    @State private var showVisionTestResponse = false
    @State private var primaryModelDisclosureExpanded: Bool = true
    @State private var taggingModelDisclosureExpanded: Bool = false
    @State private var visionModelDisclosureExpanded: Bool = false
    @State private var visionTestJPEG: Data?
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
    @State private var showResetWebProcessingConfirm = false
    @State private var isResettingWebProcessingQueue = false

    private enum ModelTestPhase {
        case idle
        case running
        case succeeded(summary: String, raw: String, subtitle: String?)
        case failed(message: String)
    }

    enum ImportPickerMode: String {
        case primaryModel
        case taggingModel
        case visionTextModel
        case visionMmprojModel
        case backup
    }

    // Fallbacks must stay in sync with MARKETING_VERSION / CURRENT_PROJECT_VERSION in project.pbxproj.
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.7.1"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "89"
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

    private var canRunVisionTest: Bool {
        ModelManager.hasReadableVisionSelection
            && visionTestJPEG.map { !$0.isEmpty } == true
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
        case .primaryModel, .taggingModel, .visionTextModel, .visionMmprojModel:
            return [UTType(filenameExtension: "gguf") ?? .data, .data]
        case .backup:
            return [.json]
        case nil:
            return [.data]
        }
    }

    private var resetProcessingQueueConfirmationMessage: String {
        """
        Stops summaries and tagging in progress when possible (one fetch may finish). Rewinds \(activeWebProcessingQueueCount) item\(activeWebProcessingQueueCount == 1 ? "" : "s") across web, notes, and photos to queued or analyzing (clears incomplete AI outputs). Completed and failed rows are untouched. Tap the Library play button later to resume.
        """
    }

    /// Settings editorial stack top inset (§3.10 / Phase 0 wiring — ~4pt, not tab-root 12pt).
    private static let editorialTopInset: CGFloat = 4

    private var settingsGroupedCornerRadius: CGFloat { AppSpacing.cardCornerRadius }

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
                case .visionTextModel:
                    handleVisionTextModelImportSelection(result)
                case .visionMmprojModel:
                    handleVisionMmprojModelImportSelection(result)
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
            .confirmationDialog(
                "Reset web processing?",
                isPresented: $showResetWebProcessingConfirm,
                titleVisibility: .visible
            ) {
                Button("Reset \(activeWebProcessingQueueCount) item(s)", role: .destructive) {
                    Task { @MainActor in
                        isResettingWebProcessingQueue = true
                        await BackgroundPipeline.resetActiveWebQueue()
                        refreshActiveWebProcessingQueueCount()
                        isResettingWebProcessingQueue = false
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(resetProcessingQueueConfirmationMessage)
            }
    }

    private var baseConfiguredForm: some View {
        settingsForm
            .scrollContentBackground(.hidden)
            .background(AppPalette.background)
            .tint(AppPalette.accent)
            .foregroundStyle(AppPalette.textPrimary)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                DetailPushNavBar()
            }
            .onAppear {
                refreshSelectionState()
                refreshArchivedCount()
                refreshActiveWebProcessingQueueCount()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    ModelManager.validateSelection()
                    ModelManager.validateTaggingSelection()
                    ModelManager.validateVisionSelection()
                    refreshSelectionState()
                    refreshArchivedCount()
                    refreshActiveWebProcessingQueueCount()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .phathomLibraryContentDidChange)) { _ in
                refreshActiveWebProcessingQueueCount()
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
    }

    private var settingsForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                EditorialScreenTitle(title: "Settings")
                VStack(alignment: .leading, spacing: AppSpacing.sectionVerticalGap) {
                    aiModelsGroupedSection
                    libraryGroupedSection
                    dataGroupedSection
                    settingsScreenFooter
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, Self.editorialTopInset)
            .padding(.bottom, AppSpacing.sectionVerticalGap)
        }
    }

    private var aiModelsGroupedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZoneSectionHeader(
                title: "AI Models",
                subtitle: "On-device models for summarization, tagging, and photo vision"
            )
            settingsGroupedSurface {
                VStack(spacing: 0) {
                    DisclosureGroup(isExpanded: $primaryModelDisclosureExpanded) {
                        modelDisclosureExpandedContent(
                            role: .primary,
                            state: selectionState,
                            testPhase: primaryTestPhase,
                            testRows: { primaryTestPhaseRows },
                            hasBookmark: ModelManager.hasBookmark,
                            isTestRunning: isPrimaryTestRunning,
                            canRunTest: canRunPrimaryTest,
                            onSelect: {
                                requestedImporter = .primaryModel
                            },
                            onTest: { runPrimaryModelTest() },
                            onForget: {
                                ModelManager.clearSelection()
                                primaryTestPhase = .idle
                                showPrimaryTestResponse = false
                                refreshSelectionState()
                            }
                        )
                        .padding(.bottom, 12)
                    } label: {
                        HStack {
                            Text("Primary model")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppPalette.textPrimary)
                            Spacer(minLength: 8)
                            modelSelectionIndicator(for: selectionState, rolePhrase: "Primary model")
                        }
                        .padding(.vertical, SettingsCardCell.verticalPadding)
                        .contentShape(Rectangle())
                    }
                    .padding(.horizontal, SettingsCardCell.horizontalPadding)
                    .tint(AppPalette.accent)

                    settingsGroupedDivider

                    DisclosureGroup(isExpanded: $taggingModelDisclosureExpanded) {
                        modelDisclosureExpandedContent(
                            role: .tagging,
                            state: taggingSelectionState,
                            testPhase: taggingTestPhase,
                            testRows: { taggingTestPhaseRows },
                            hasBookmark: ModelManager.hasTaggingBookmark,
                            isTestRunning: isTaggingTestRunning,
                            canRunTest: canRunTaggingTest,
                            onSelect: {
                                requestedImporter = .taggingModel
                            },
                            onTest: { runTaggingModelTest() },
                            onForget: {
                                ModelManager.clearTaggingSelection()
                                taggingTestPhase = .idle
                                showTaggingTestResponse = false
                                refreshSelectionState()
                            }
                        )
                        .padding(.bottom, 8)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Tagging model")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppPalette.textPrimary)
                            Text("(optional)")
                                .font(.subheadline)
                                .foregroundStyle(AppPalette.textSecondary)
                            Spacer(minLength: 8)
                            modelSelectionIndicator(for: taggingSelectionState, rolePhrase: "Tagging model")
                        }
                        .padding(.vertical, SettingsCardCell.verticalPadding)
                        .contentShape(Rectangle())
                    }
                    .padding(.horizontal, SettingsCardCell.horizontalPadding)
                    .tint(AppPalette.accent)

                    settingsGroupedDivider

                    VisionModelSettingsSection(
                        textState: visionTextSelectionState,
                        mmprojState: visionMmprojSelectionState,
                        testPhase: visionTestPhase,
                        showTestResponse: $showVisionTestResponse,
                        hasAnyBookmark: ModelManager.hasVisionTextBookmark || ModelManager.hasVisionMmprojBookmark,
                        isTestRunning: isVisionTestRunning,
                        canRunTest: canRunVisionTest,
                        disclosureExpanded: $visionModelDisclosureExpanded,
                        testJPEG: $visionTestJPEG,
                        onPickTextGGUF: {
                            requestedImporter = .visionTextModel
                        },
                        onPickMmproj: {
                            requestedImporter = .visionMmprojModel
                        },
                        onTest: { runVisionModelTest() },
                        onForget: {
                            ModelManager.clearVisionSelection()
                            visionTestPhase = .idle
                            showVisionTestResponse = false
                            visionTestJPEG = nil
                            refreshSelectionState()
                        }
                    )
                }
            }
        }
    }

    /// Full-width separator inside a padded `DisclosureGroup` interior (avoid double-leading inset).
    private var settingsGroupedInteriorDivider: some View {
        Divider()
            .overlay(AppPalette.textTertiary.opacity(0.35))
    }

    /// Inset divider between sibling rows inside a grouped card (`Form`-style grouping).
    private var settingsGroupedDivider: some View {
        Divider()
            .overlay(AppPalette.textTertiary.opacity(0.35))
            .padding(.leading, SettingsCardCell.horizontalPadding)
    }

    @ViewBuilder
    private func settingsGroupedSurface<C: View>(@ViewBuilder content: () -> C) -> some View {
        content()
            .frame(maxWidth: .infinity)
            .background(AppPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: settingsGroupedCornerRadius, style: .continuous))
    }

    @ViewBuilder
    private func modelSelectionIndicator(for state: ModelManager.SelectionDisplayState, rolePhrase: String) -> some View {
        switch state {
        case .ready:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .imageScale(.medium)
                .accessibilityLabel("\(rolePhrase) selected")
        case .noSelection:
            Image(systemName: "circle")
                .foregroundStyle(AppPalette.textSecondary)
                .imageScale(.medium)
                .accessibilityLabel("\(rolePhrase) not selected")
        case .missingFile:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .imageScale(.medium)
                .accessibilityLabel("\(rolePhrase) file missing")
        }
    }

    private enum ModelDisclosureRole {
        case primary
        case tagging
    }

    /// Expanded-only body for Primary / Tagging model `DisclosureGroup`. Collapsed labels stay untouched.
    @ViewBuilder
    private func modelDisclosureExpandedContent<TR: View>(
        role: ModelDisclosureRole,
        state: ModelManager.SelectionDisplayState,
        testPhase: ModelTestPhase,
        @ViewBuilder testRows: () -> TR,
        hasBookmark: Bool,
        isTestRunning: Bool,
        canRunTest: Bool,
        onSelect: @escaping () -> Void,
        onTest: @escaping () -> Void,
        onForget: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            settingsGroupedInteriorDivider

            Group {
                switch state {
                case .noSelection:
                    Text(role == .primary
                        ? "No primary model selected."
                        : "No optional tagging model — tags use the primary model.")
                        .foregroundStyle(AppPalette.textSecondary)

                case .ready(let name, let byteString):
                    SettingsModelFileInfoBlock(fileName: name, byteString: byteString)

                case .missingFile:
                    VStack(alignment: .leading, spacing: 6) {
                        Text(role == .primary
                            ? "Primary model file not found"
                            : "Tagging model file not found")
                            .foregroundStyle(.orange)
                        Text(role == .primary
                            ? "The file may have moved or been deleted. Choose a new primary model or forget this selection."
                            : "Tagging will use the primary model until you pick a new tagging file or forget this selection.")
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
                title: modelDisclosureSelectRowTitle(role: role, state: state),
                iconName: "arrow.down.doc.fill",
                iconTint: AppPalette.accent,
                foreground: AppPalette.accent,
                disabled: false,
                action: onSelect
            )
            .padding(.horizontal, SettingsCardCell.horizontalPadding)

            settingsGroupedInteriorDivider

            SettingsModelActionRow(
                title: "Test model",
                iconName: "play.fill",
                iconTint: AppPalette.textPrimary,
                foreground: AppPalette.textPrimary,
                disabled: isTestRunning || !canRunTest,
                action: onTest
            )
            .padding(.horizontal, SettingsCardCell.horizontalPadding)

            if case .idle = testPhase {
                EmptyView()
            } else {
                settingsGroupedInteriorDivider
                testRows()
                    .padding(.horizontal, SettingsCardCell.horizontalPadding)
                    .padding(.vertical, SettingsCardCell.verticalPadding)
            }

            if hasBookmark {
                settingsGroupedInteriorDivider
                SettingsModelActionRow(
                    title: "Forget model",
                    iconName: "trash.fill",
                    iconTint: Color.red,
                    foreground: Color.red,
                    disabled: false,
                    action: onForget
                )
                .padding(.horizontal, SettingsCardCell.horizontalPadding)
            }

            if case .ready = state {
                settingsGroupedInteriorDivider
                SettingsModelInfoFooter(
                    text: role == .primary
                        ? "Used for summaries, extracts, semantic search, related items, and as fallback for tagging."
                        : "Used only when automatically tagging items or tapping Regenerate tags. Falls back to primary."
                )
                .padding(.horizontal, SettingsCardCell.horizontalPadding)
                .padding(.vertical, SettingsCardCell.verticalPadding)
            }
        }
    }

    private func modelDisclosureSelectRowTitle(
        role: ModelDisclosureRole,
        state: ModelManager.SelectionDisplayState
    ) -> String {
        switch state {
        case .noSelection:
            return role == .primary ? "Select primary model" : "Select tagging model"
        case .ready, .missingFile:
            return "Select different model"
        }
    }

    private var libraryGroupedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZoneSectionHeader(title: "Library")
            settingsGroupedSurface {
                VStack(spacing: 0) {
                    NavigationLink {
                        RecentlyDeletedView()
                    } label: {
                        HStack {
                            Text("Recently Deleted")
                                .foregroundStyle(AppPalette.textPrimary)
                            Spacer()
                            if archivedCount > 0 {
                                Text("\(archivedCount)")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(AppPalette.textPrimary)
                                    .padding(.horizontal, 7)
                                    .frame(minWidth: 24, minHeight: 24)
                                    .background(AppPalette.surfaceNested)
                                    .clipShape(Capsule())
                                    .minimumScaleFactor(0.8)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, SettingsCardCell.horizontalPadding)
                        .padding(.vertical, SettingsCardCell.verticalPadding)
                        .frame(maxWidth: .infinity)
                    }

                    settingsGroupedDivider

                    Button {
                        showResetWebProcessingConfirm = true
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Reset processing queue")
                                .font(.body)
                                .foregroundStyle(AppPalette.textPrimary)
                                .multilineTextAlignment(.leading)
                            Text("Clears processing data and retries incomplete web, note, and photo items")
                                .font(.footnote)
                                .foregroundStyle(AppPalette.textSecondary)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .disabled(activeWebProcessingQueueCount == 0 || isResettingWebProcessingQueue)
                    .opacity((activeWebProcessingQueueCount == 0 || isResettingWebProcessingQueue) ? 0.45 : 1)
                    .padding(.horizontal, SettingsCardCell.horizontalPadding)
                    .padding(.vertical, SettingsCardCell.verticalPadding)
                }
            }
        }
    }

    private var dataGroupedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZoneSectionHeader(title: "Data")
            settingsGroupedSurface {
                VStack(spacing: 0) {
                    Button {
                        exportLibraryBackup()
                    } label: {
                        Label("Export Library", systemImage: "square.and.arrow.up")
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(AppPalette.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .disabled(backupBusy)
                    .padding(.horizontal, SettingsCardCell.horizontalPadding)
                    .padding(.vertical, SettingsCardCell.verticalPadding)

                    settingsGroupedDivider

                    Button {
                        requestedImporter = .backup
                    } label: {
                        Label("Import Library", systemImage: "square.and.arrow.down")
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(AppPalette.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .disabled(backupBusy)
                    .padding(.horizontal, SettingsCardCell.horizontalPadding)
                    .padding(.vertical, SettingsCardCell.verticalPadding)
                }
            }
        }
    }

    private var settingsScreenFooter: some View {
        VStack(spacing: 6) {
            Text("Phathom v\(appVersion) (\(build))")
            Text("Your data stays on your device")
        }
        .font(.footnote)
        .foregroundStyle(AppPalette.textSecondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
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
                FlatToolbarTextItem(
                    title: "Done",
                    placement: .confirmationAction,
                    foreground: AppPalette.accent
                ) {
                    showImportErrorSheet = false
                }
            }
        }
        .tint(AppPalette.accent)
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

    private func refreshActiveWebProcessingQueueCount() {
        activeWebProcessingQueueCount = BackgroundPipeline.activeQueueResetEligibleCount(in: modelContext)
    }

    private func refreshSelectionState() {
        ModelManager.validateSelection()
        ModelManager.validateTaggingSelection()
        ModelManager.validateVisionSelection()
        let next = ModelManager.selectionDisplayState()
        selectionState = next
        taggingSelectionState = ModelManager.taggingSelectionDisplayState()
        visionTextSelectionState = ModelManager.visionTextSelectionDisplayState()
        visionMmprojSelectionState = ModelManager.visionMmprojSelectionDisplayState()
        switch next {
        case .ready:
            primaryModelDisclosureExpanded = false
        case .noSelection, .missingFile:
            primaryModelDisclosureExpanded = true
        }
        switch taggingSelectionState {
        case .ready:
            taggingModelDisclosureExpanded = false
        case .noSelection:
            taggingModelDisclosureExpanded = false
        case .missingFile:
            taggingModelDisclosureExpanded = true
        }
        switch (visionTextSelectionState, visionMmprojSelectionState) {
        case (.ready, .ready):
            visionModelDisclosureExpanded = false
        case (.noSelection, .noSelection):
            visionModelDisclosureExpanded = false
        default:
            if case .missingFile = visionTextSelectionState { visionModelDisclosureExpanded = true }
            if case .missingFile = visionMmprojSelectionState { visionModelDisclosureExpanded = true }
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

    private func runVisionModelTest() {
        guard let jpeg = visionTestJPEG, !jpeg.isEmpty else { return }
        visionTestPhase = .running
        showVisionTestResponse = false
        Task {
            do {
                let description = try await VisionModelSmokeTest.describe(jpegData: jpeg)
                await MainActor.run {
                    visionTestPhase = .succeeded(
                        summary: "Vision model responded successfully.",
                        raw: description
                    )
                }
            } catch {
                await MainActor.run {
                    visionTestPhase = .failed(message: error.localizedDescription)
                }
            }
        }
    }

    private var isVisionTestRunning: Bool {
        if case .running = visionTestPhase {
            return true
        }
        return false
    }

    private func handleVisionTextModelImportSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let src = urls.first else { return }
            do {
                try ModelManager.setVisionTextSelection(from: src)
                visionTestPhase = .idle
                showVisionTestResponse = false
                refreshSelectionState()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } catch {
                importerError = error.localizedDescription
            }
        case .failure(let error):
            importerError = error.localizedDescription
        }
    }

    private func handleVisionMmprojModelImportSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let src = urls.first else { return }
            do {
                try ModelManager.setVisionMmprojSelection(from: src)
                visionTestPhase = .idle
                showVisionTestResponse = false
                refreshSelectionState()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } catch {
                importerError = error.localizedDescription
            }
        case .failure(let error):
            importerError = error.localizedDescription
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

private struct SettingsModelIconWell: View {
    let systemName: String
    var foreground: Color = AppPalette.textPrimary

    var body: some View {
        ZStack {
            Circle()
                .fill(AppPalette.surfaceNested)
                .frame(width: SettingsModelIcons.wellDiameter, height: SettingsModelIcons.wellDiameter)
            Image(systemName: systemName)
                .font(.system(size: SettingsModelIcons.symbolFontSize, weight: .semibold))
                .foregroundStyle(foreground)
                .symbolRenderingMode(.hierarchical)
        }
        .accessibilityHidden(true)
    }
}

private enum SettingsModelIcons {
    static let wellDiameter: CGFloat = 32
    static let symbolFontSize: CGFloat = 14
}

struct SettingsModelActionRow: View {
    let title: String
    let iconName: String
    let iconTint: Color
    let foreground: Color
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                SettingsModelIconWell(systemName: iconName, foreground: iconTint)
                Text(title)
                    .font(.body)
                    .foregroundStyle(disabled ? AppPalette.textTertiary : foreground)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
        .padding(.vertical, SettingsCardCell.verticalPadding)
        .accessibilityLabel(title)
    }
}

struct SettingsModelFileInfoBlock: View {
    let fileName: String
    let byteString: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Selected file")
                .font(.footnote)
                .foregroundStyle(AppPalette.textSecondary)
            Text(fileName)
                .font(.body)
                .foregroundStyle(AppPalette.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Text(byteString)
                .font(.footnote)
                .foregroundStyle(AppPalette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsModelInfoFooter: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.footnote)
                .foregroundStyle(AppPalette.textSecondary)
            Text(text)
                .font(.footnote)
                .foregroundStyle(AppPalette.textSecondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum SettingsCardCell {
    static let horizontalPadding: CGFloat = 16
    static let verticalPadding: CGFloat = 12
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
        }
    }
}

#Preview {
    SettingsTab()
}



