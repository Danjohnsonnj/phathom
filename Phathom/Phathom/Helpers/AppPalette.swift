import PhathomCore
import SwiftUI

/// Phathom dark theme palette (CSS variables as Swift).
enum AppPalette {
    static let floralWhite = Color(hex: "#fffcf2")
    static let dustGrey = Color(hex: "#ccc5b9")
    static let charcoalBrown = Color(hex: "#403d39")
    static let carbonBlack = Color(hex: "#252422")
    static let spicyPaprika = Color(hex: "#eb5e28")

    /// Meta chips: processing / pending / failed on library rows.
    static let metaChipBackground = Color(hex: "#401F12")

    static let background = carbonBlack
    static let surface = charcoalBrown
    static let textPrimary = floralWhite
    static let textSecondary = dustGrey
    static let accent = spicyPaprika

    /// Subtle lift between background and `surface` for nested blocks.
    static let surfaceNested = Color(hex: "#353330")

    static let textTertiary = dustGrey.opacity(0.72)

    /// Default when `thumbnailColorHex` is missing.
    static let thumbnailFallbackHex = "#403d39"

    /// Deterministic placeholder thumbnail hues (palette-only).
    static let thumbnailHexCycle: [String] = [
        "#eb5e28", "#403d39", "#ccc5b9", "#252422",
        "#5c534c", "#8b4a2c", "#6b6560", "#3d3a37",
    ]
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgbValue: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgbValue)
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
