import PhathomCore
import SwiftUI

struct FocusRevisitScheduleSheet: View {
    let item: ContentItem
    let onSchedule: (Date) -> Void
    let onCancel: () -> Void

    @State private var showsCustomPicker = false
    @State private var customDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: .now) ?? .now

    private var calendar: Calendar { .current }

    private static let presetDateFormat = Date.FormatStyle()
        .weekday(.abbreviated)
        .month(.abbreviated)
        .day()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(item.displayTitle)
                        .appTypography(.zoneSubtitle)
                        .foregroundStyle(AppPalette.textSecondary)
                        .lineLimit(2)

                    VStack(spacing: 0) {
                        scheduleRow(title: "1 week", date: oneWeekDate)
                        sheetHairline
                        scheduleRow(title: "1 month", date: oneMonthDate)
                        sheetHairline
                        Button {
                            withAnimation {
                                showsCustomPicker.toggle()
                            }
                        } label: {
                            HStack {
                                Text("Custom date")
                                    .appTypography(.bodyMedium)
                                    .foregroundStyle(AppPalette.textPrimary)
                                Spacer(minLength: 8)
                                Text(showsCustomPicker ? "Hide" : "Choose")
                                    .appTypography(.zoneSubtitle)
                                    .foregroundStyle(AppPalette.accent)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)

                        if showsCustomPicker {
                            sheetHairline
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Resurfaces \(customDate.formatted(Self.presetDateFormat))")
                                    .appTypography(.zoneSubtitle)
                                    .foregroundStyle(AppPalette.textSecondary)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 12)

                                DatePicker(
                                    "Resurface on",
                                    selection: $customDate,
                                    in: earliestCustomDate...,
                                    displayedComponents: [.date]
                                )
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .padding(.horizontal, 16)

                                Button {
                                    onSchedule(startOfDay(customDate))
                                } label: {
                                    Text("Schedule")
                                        .appTypography(.disclosureLabel)
                                        .phathomCapsuleCTALabel()
                                        .foregroundStyle(AppPalette.floralWhite)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(AppPalette.accent)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 14)
                            }
                        }
                    }
                    .background(AppPalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .fixedSize(horizontal: false, vertical: true)
                .phathomSheetHeightMeasurable()
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.bottom, 24)
            }
            .background(AppPalette.background)
            .navigationTitle("Revisit")
            .phathomInlineNavigationTitle()
            .toolbar {
                FlatToolbarTextItem(
                    title: "Cancel",
                    placement: .cancellationAction,
                    foreground: AppPalette.accent,
                    action: onCancel
                )
            }
        }
        .phathomSheetPresentation()
        .onAppear {
            customDate = max(oneWeekDate, earliestCustomDate)
        }
    }

    private var earliestCustomDate: Date {
        startOfDay(calendar.date(byAdding: .day, value: 1, to: .now) ?? .now)
    }

    private var oneWeekDate: Date {
        let base = calendar.date(byAdding: .weekOfYear, value: 1, to: .now) ?? .now
        return startOfDay(base)
    }

    private var oneMonthDate: Date {
        let base = calendar.date(byAdding: .month, value: 1, to: .now) ?? .now
        return startOfDay(base)
    }

    private func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    private func scheduleRow(title: String, date: Date) -> some View {
        Button {
            onSchedule(date)
        } label: {
            HStack {
                Text(title)
                    .appTypography(.bodyMedium)
                    .foregroundStyle(AppPalette.textPrimary)
                Spacer(minLength: 8)
                Text(date.formatted(Self.presetDateFormat))
                    .appTypography(.zoneSubtitle)
                    .foregroundStyle(AppPalette.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    private var sheetHairline: some View {
        Rectangle()
            .fill(AppPalette.hairline)
            .frame(height: 1)
            .padding(.leading, 16)
    }
}
