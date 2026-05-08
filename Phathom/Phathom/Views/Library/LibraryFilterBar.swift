import PhathomCore
import SwiftUI

/// Two filter controls above the Library list. Uses anchored `popover` (not `Menu`) so presentation stays
/// below each capsule and avoids UIMenu / `_UIReparentingView` issues with `NavigationStack` + `List` + `.searchable`.
/// "Type" filters by `ContentKind`; "Status" filters by `ReadStatus`. `nil` selection = "All".
struct LibraryFilterBar: View {
    @Binding var selectedKind: ContentKind?
    @Binding var selectedStatus: ReadStatus?

    @State private var showKindPicker = false
    @State private var showStatusPicker = false

    var body: some View {
        HStack(spacing: 10) {
            kindTrigger
            statusTrigger
            Spacer(minLength: 0)
        }
    }

    private var kindTrigger: some View {
        Button {
            showStatusPicker = false
            showKindPicker = true
        } label: {
            FilterMenuLabel(label: "Type", value: kindLabel, maxValue: "Media")
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filter by type")
        .accessibilityValue(kindLabel)
        .popover(isPresented: $showKindPicker, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
            kindPickerPanel
                .presentationCompactAdaptation(.popover)
        }
    }

    private var statusTrigger: some View {
        Button {
            showKindPicker = false
            showStatusPicker = true
        } label: {
            FilterMenuLabel(label: "Status", value: statusLabel, maxValue: "Filed")
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filter by status")
        .accessibilityValue(statusLabel)
        .popover(isPresented: $showStatusPicker, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
            statusPickerPanel
                .presentationCompactAdaptation(.popover)
        }
    }

    private var kindPickerPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            filterPopoverRow(title: "All", selected: selectedKind == nil) {
                selectedKind = nil
                showKindPicker = false
            }
            filterPopoverRow(title: "Web", selected: selectedKind == .web) {
                selectedKind = .web
                showKindPicker = false
            }
            filterPopoverRow(title: "Media", selected: selectedKind == .media) {
                selectedKind = .media
                showKindPicker = false
            }
            filterPopoverRow(title: "Notes", selected: selectedKind == .note) {
                selectedKind = .note
                showKindPicker = false
            }
        }
        .frame(minWidth: 200)
        .padding(.vertical, 6)
    }

    private var statusPickerPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            filterPopoverRow(title: "All", selected: selectedStatus == nil) {
                selectedStatus = nil
                showStatusPicker = false
            }
            filterPopoverRow(title: "New", selected: selectedStatus == .new) {
                selectedStatus = .new
                showStatusPicker = false
            }
            filterPopoverRow(title: "Read", selected: selectedStatus == .read) {
                selectedStatus = .read
                showStatusPicker = false
            }
            filterPopoverRow(title: "Filed", selected: selectedStatus == .filed) {
                selectedStatus = .filed
                showStatusPicker = false
            }
        }
        .frame(minWidth: 200)
        .padding(.vertical, 6)
    }

    private func filterPopoverRow(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.body)
                    .foregroundStyle(AppPalette.textPrimary)
                Spacer(minLength: 12)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppPalette.accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
