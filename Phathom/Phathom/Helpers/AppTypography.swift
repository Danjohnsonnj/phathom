import SwiftUI

// MARK: - Preference storage

enum AppTextSizeStorage {
    static let key = "display.textSize"
}

enum AppTextSizePreference: String, CaseIterable, Identifiable {
    case xs
    case s
    case m
    case l
    case xl

    var id: String { rawValue }

    var multiplier: CGFloat {
        switch self {
        case .xs: 0.80
        case .s: 0.90
        case .m: 1.00
        case .l: 1.15
        case .xl: 1.30
        }
    }

    var segmentTitle: String {
        switch self {
        case .xs: "XS"
        case .s: "S"
        case .m: "M"
        case .l: "L"
        case .xl: "XL"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .xs: "Smallest"
        case .s: "Small"
        case .m: "Normal"
        case .l: "Large"
        case .xl: "Largest"
        }
    }

    static var `default`: AppTextSizePreference { .m }
}

// MARK: - Scale math

struct TypographyScale: Equatable, Sendable {
    let multiplier: CGFloat

    init(multiplier: CGFloat) {
        self.multiplier = multiplier
    }

    init(preference: AppTextSizePreference) {
        self.multiplier = preference.multiplier
    }

    static let normal = TypographyScale(multiplier: 1.0)

    func scaled(_ base: CGFloat) -> CGFloat {
        let raw = base * multiplier
        let rounded = (raw * 2).rounded() / 2
        return max(11, rounded)
    }

    func scaledTracking(_ base: CGFloat) -> CGFloat {
        base * multiplier
    }

    func scaledLineSpacing(_ base: CGFloat) -> CGFloat {
        base * multiplier
    }
}

// MARK: - Design-token roles

enum AppTypography {
    case screenTitle
    case zoneHeader
    case zoneSubtitle
    case subsectionHeader
    case galleryTitle
    case sourceLine
    case emptyPrimary
    case emptyHint
    case meta
    case disclosureLabel
    case body
    case bodyMedium
    case bodySemibold
    case footnote
    case captionSemibold
    case filterLabel
    case tagChip
    case noteLabel
    case searchField
    case addNewAccentLabel
    case detailTitle

    fileprivate var baseSize: CGFloat {
        switch self {
        case .screenTitle: 34
        case .zoneHeader, .emptyPrimary, .body, .bodyMedium, .bodySemibold: 17
        case .zoneSubtitle, .emptyHint, .subsectionHeader, .disclosureLabel, .filterLabel: 15
        case .galleryTitle, .searchField: 16
        case .sourceLine, .footnote, .tagChip, .addNewAccentLabel: 13
        case .meta, .captionSemibold: 12
        case .noteLabel: 11
        case .detailTitle: 28
        }
    }

    fileprivate var weight: Font.Weight {
        switch self {
        case .screenTitle, .zoneHeader, .emptyPrimary, .bodySemibold, .disclosureLabel, .addNewAccentLabel, .captionSemibold:
            .semibold
        case .subsectionHeader, .galleryTitle, .bodyMedium, .tagChip, .noteLabel:
            .medium
        case .filterLabel:
            .light
        case .detailTitle:
            .bold
        default:
            .regular
        }
    }

    fileprivate var tracking: CGFloat? {
        switch self {
        case .screenTitle: -1.02
        case .zoneHeader, .emptyPrimary: -0.34
        case .subsectionHeader: -0.15
        case .galleryTitle: -0.32
        case .meta: 0.24
        case .tagChip: -0.13
        case .noteLabel: 0.44
        case .addNewAccentLabel: 0.6
        default: nil
        }
    }

    fileprivate var lineSpacing: CGFloat? {
        switch self {
        case .screenTitle: 3.4
        default: nil
        }
    }

    func font(scale: TypographyScale) -> Font {
        .system(size: scale.scaled(baseSize), weight: weight)
    }
}

// MARK: - Environment

private struct TypographyScaleKey: EnvironmentKey {
    static let defaultValue = TypographyScale.normal
}

extension EnvironmentValues {
    var typographyScale: TypographyScale {
        get { self[TypographyScaleKey.self] }
        set { self[TypographyScaleKey.self] = newValue }
    }
}

extension View {
    func typographyScaleOverride(_ multiplier: CGFloat?) -> some View {
        transformEnvironment(\.typographyScale) { current in
            if let multiplier {
                current = TypographyScale(multiplier: multiplier)
            }
        }
    }

    func appTypography(_ role: AppTypography) -> some View {
        modifier(AppTypographyModifier(role: role))
    }
}

private struct AppTypographyModifier: ViewModifier {
    @Environment(\.typographyScale) private var scale
    let role: AppTypography

    func body(content: Content) -> some View {
        var view = AnyView(
            content
                .font(role.font(scale: scale))
        )
        if let tracking = role.tracking {
            view = AnyView(view.tracking(scale.scaledTracking(tracking)))
        }
        if let lineSpacing = role.lineSpacing {
            view = AnyView(view.lineSpacing(scale.scaledLineSpacing(lineSpacing)))
        }
        return view
    }
}

// MARK: - Root injection

struct TypographyEnvironmentRoot<Content: View>: View {
    @AppStorage(AppTextSizeStorage.key) private var textSizeRaw: String = AppTextSizePreference.default.rawValue

    @ViewBuilder var content: () -> Content

    private var scale: TypographyScale {
        let pref = AppTextSizePreference(rawValue: textSizeRaw) ?? .default
        return TypographyScale(preference: pref)
    }

    var body: some View {
        content()
            .environment(\.typographyScale, scale)
    }
}
