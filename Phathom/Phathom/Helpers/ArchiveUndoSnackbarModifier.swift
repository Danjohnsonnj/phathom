import PhathomCore
import SwiftData
import SwiftUI

/// Batch archive undo snackbar shared by iOS `MainTabView` and macOS `MainMacView`.
struct ArchiveUndoSnackbarModifier: ViewModifier {
    @Environment(\.modelContext) private var modelContext

    let isSnackbarVisible: Bool
    let onSwitchToLibrary: () -> Void

    @State private var undoArchiveBatch: [UUID]?
    @State private var undoArchiveTask: Task<Void, Never>?

    private static let fade = Animation.easeInOut(duration: 0.25)

    private var message: String {
        let n = undoArchiveBatch?.count ?? 0
        if n <= 1 {
            return "Archived. You can restore it from Recently Deleted within 2 days."
        }
        return "Archived \(n) items. You can restore them from Recently Deleted within 2 days."
    }

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .phathomDidArchiveItem)) { note in
                guard let ids = PhathomArchiveNotification.itemIDs(from: note.userInfo), !ids.isEmpty else { return }
                let switchToLibrary = note.userInfo?[PhathomArchiveNotification.switchToLibraryKey] as? Bool ?? true
                if switchToLibrary, !isSnackbarVisible {
                    onSwitchToLibrary()
                }
                startArchiveUndo(for: ids)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if isSnackbarVisible, let batch = undoArchiveBatch, !batch.isEmpty {
                    HStack(alignment: .center, spacing: 12) {
                        Text(message)
                            .appTypography(.footnote)
                            .foregroundStyle(AppPalette.textPrimary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 8)
                        Button {
                            performUndoArchive()
                        } label: {
                            Text("Undo")
                                .phathomToolbarTextLabel()
                                .appTypography(.captionSemibold)
                        }
                        .foregroundStyle(AppPalette.accent)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(AppPalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppPalette.textTertiary.opacity(0.35), lineWidth: 1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, snackbarBottomInset)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(Self.fade, value: undoArchiveBatch)
            .animation(Self.fade, value: isSnackbarVisible)
    }

    private var snackbarBottomInset: CGFloat {
        #if os(iOS)
        52
        #else
        16
        #endif
    }

    private func startArchiveUndo(for ids: [UUID]) {
        withAnimation(Self.fade) {
            undoArchiveBatch = ids
        }
        undoArchiveTask?.cancel()
        undoArchiveTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(Self.fade) {
                undoArchiveBatch = nil
            }
        }
    }

    private func performUndoArchive() {
        undoArchiveTask?.cancel()
        guard let batch = undoArchiveBatch, !batch.isEmpty else { return }
        for id in batch {
            let rowID = id
            let fd = FetchDescriptor<ContentItem>(predicate: #Predicate<ContentItem> { $0.id == rowID })
            if let item = try? modelContext.fetch(fd).first {
                ArchiveRetention.restore(item)
            }
        }
        try? modelContext.save()
        LibraryContentChangeNotifier.postLibraryContentDidChange()
        withAnimation(Self.fade) {
            undoArchiveBatch = nil
        }
    }
}

extension View {
    func archiveUndoSnackbar(isVisible: Bool, onSwitchToLibrary: @escaping () -> Void) -> some View {
        modifier(ArchiveUndoSnackbarModifier(isSnackbarVisible: isVisible, onSwitchToLibrary: onSwitchToLibrary))
    }
}
