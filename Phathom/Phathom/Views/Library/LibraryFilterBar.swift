import PhathomCore
import SwiftUI

/// Two-dropdown filter row above the Library list. Replaces the older `FilterPills`.
/// "Type" filters by `ContentKind`; "Status" filters by `ReadStatus`. `nil` selection = "All".
struct LibraryFilterBar: View {
    @Binding var selectedKind: ContentKind?
    @Binding var selectedStatus: ReadStatus?

    var body: some View {
        HStack(spacing: 10) {
            kindMenu
            statusMenu
            Spacer(minLength: 0)
        }
    }

    private var kindMenu: some View {
        Menu {
            Button { selectedKind = nil } label: {
                kindMenuItem(label: "All", kind: nil)
            }
            Button { selectedKind = .web } label: {
                kindMenuItem(label: "Web", kind: .web)
            }
            Button { selectedKind = .media } label: {
                kindMenuItem(label: "Media", kind: .media)
            }
            Button { selectedKind = .note } label: {
                kindMenuItem(label: "Notes", kind: .note)
            }
        } label: {
            FilterMenuLabel(label: "Type", value: kindLabel, maxValue: "Media")
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .accessibilityLabel("Filter by type")
        .accessibilityValue(kindLabel)
    }

    private var statusMenu: some View {
        Menu {
            Button { selectedStatus = nil } label: {
                statusMenuItem(label: "All", status: nil)
            }
            Button { selectedStatus = .new } label: {
                statusMenuItem(label: "New", status: .new)
            }
            Button { selectedStatus = .read } label: {
                statusMenuItem(label: "Read", status: .read)
            }
            Button { selectedStatus = .filed } label: {
                statusMenuItem(label: "Filed", status: .filed)
            }
        } label: {
            FilterMenuLabel(label: "Status", value: statusLabel, maxValue: "Filed")
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .accessibilityLabel("Filter by status")
        .accessibilityValue(statusLabel)
    }

    private var kindLabel: String {
        switch selectedKind {
        case .none: return "All"
        case .web: return "Web"
        case .media: return "Media"
        case .note: return "Notes"
        }
    }

    private var statusLabel: String {
        switch selectedStatus {
        case .none: return "All"
        case .new: return "New"
        case .read: return "Read"
        case .filed: return "Filed"
        }
    }

    @ViewBuilder
    private func kindMenuItem(label: String, kind: ContentKind?) -> some View {
        if selectedKind == kind {
            Label(label, systemImage: "checkmark")
        } else {
            Text(label)
        }
    }

    @ViewBuilder
    private func statusMenuItem(label: String, status: ReadStatus?) -> some View {
        if selectedStatus == status {
            Label(label, systemImage: "checkmark")
        } else {
            Text(label)
        }
    }
}

/// Capsule label matching the existing pill aesthetic. Wraps "Label: Value" + chevron.
private struct FilterMenuLabel: View {
    let label: String
    let value: String
    let maxValue: String

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppPalette.textSecondary)
            ZStack(alignment: .leading) {
                Text(maxValue)
                    .font(.subheadline.weight(.semibold))
                    .hidden()
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.textPrimary)
            }
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppPalette.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(AppPalette.surface))
        .contentShape(Capsule())
    }
}

#Preview {
    struct Binder: View {
        @State private var kind: ContentKind?
        @State private var status: ReadStatus?
        var body: some View {
            LibraryFilterBar(selectedKind: $kind, selectedStatus: $status)
                .padding()
        }
    }
    return Binder()
        .background(AppPalette.background)
}
