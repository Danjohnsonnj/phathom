import PhathomCore
import MarkdownUI
import SwiftUI

extension Theme {
    /// Markdown tuned for the Note card on detail: flat against `AppPalette.surface`, code blocks use `surfaceNested`.
    static var phathomNote: Theme {
        Theme.gitHub
            .text {
                ForegroundColor(AppPalette.textPrimary)
                BackgroundColor(Color.clear)
                FontSize(16)
            }
            .code {
                FontFamilyVariant(.monospaced)
                FontSize(.em(0.85))
                BackgroundColor(AppPalette.surfaceNested.opacity(0.55))
            }
            .link {
                ForegroundColor(AppPalette.accent)
            }
            .heading1 { configuration in
                VStack(alignment: .leading, spacing: 0) {
                    configuration.label
                        .relativePadding(.bottom, length: .em(0.3))
                        .relativeLineSpacing(.em(0.125))
                        .markdownMargin(top: 24, bottom: 16)
                        .markdownTextStyle {
                            FontWeight(.semibold)
                            FontSize(.em(2))
                            ForegroundColor(AppPalette.textPrimary)
                            BackgroundColor(Color.clear)
                        }
                    Divider().overlay(AppPalette.textTertiary.opacity(0.35))
                }
            }
            .heading2 { configuration in
                VStack(alignment: .leading, spacing: 0) {
                    configuration.label
                        .relativePadding(.bottom, length: .em(0.3))
                        .relativeLineSpacing(.em(0.125))
                        .markdownMargin(top: 24, bottom: 16)
                        .markdownTextStyle {
                            FontWeight(.semibold)
                            FontSize(.em(1.5))
                            ForegroundColor(AppPalette.textPrimary)
                            BackgroundColor(Color.clear)
                        }
                    Divider().overlay(AppPalette.textTertiary.opacity(0.35))
                }
            }
            .heading3 { configuration in
                configuration.label
                    .relativeLineSpacing(.em(0.125))
                    .markdownMargin(top: 24, bottom: 16)
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(.em(1.25))
                        ForegroundColor(AppPalette.textPrimary)
                        BackgroundColor(Color.clear)
                    }
            }
            .heading4 { configuration in
                configuration.label
                    .relativeLineSpacing(.em(0.125))
                    .markdownMargin(top: 24, bottom: 16)
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        ForegroundColor(AppPalette.textPrimary)
                        BackgroundColor(Color.clear)
                    }
            }
            .heading5 { configuration in
                configuration.label
                    .relativeLineSpacing(.em(0.125))
                    .markdownMargin(top: 24, bottom: 16)
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(.em(0.875))
                        ForegroundColor(AppPalette.textPrimary)
                        BackgroundColor(Color.clear)
                    }
            }
            .heading6 { configuration in
                configuration.label
                    .relativeLineSpacing(.em(0.125))
                    .markdownMargin(top: 24, bottom: 16)
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(.em(0.85))
                        ForegroundColor(AppPalette.textTertiary)
                        BackgroundColor(Color.clear)
                    }
            }
            .paragraph { configuration in
                configuration.label
                    .fixedSize(horizontal: false, vertical: true)
                    .relativeLineSpacing(.em(0.25))
                    .markdownMargin(top: 0, bottom: 16)
                    .markdownTextStyle {
                        BackgroundColor(Color.clear)
                    }
            }
            .blockquote { configuration in
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppPalette.textTertiary.opacity(0.45))
                        .relativeFrame(width: .em(0.2))
                    configuration.label
                        .markdownTextStyle { ForegroundColor(AppPalette.textSecondary) }
                        .relativePadding(.horizontal, length: .em(1))
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .codeBlock { configuration in
                ScrollView(.horizontal) {
                    configuration.label
                        .fixedSize(horizontal: false, vertical: true)
                        .relativeLineSpacing(.em(0.225))
                        .markdownTextStyle {
                            FontFamilyVariant(.monospaced)
                            FontSize(.em(0.85))
                            ForegroundColor(AppPalette.textPrimary)
                            BackgroundColor(Color.clear)
                        }
                        .padding(16)
                }
                .background(AppPalette.surfaceNested)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .markdownMargin(top: 0, bottom: 16)
            }
            .table { configuration in
                configuration.label
                    .fixedSize(horizontal: false, vertical: true)
                    .markdownTableBorderStyle(.init(color: AppPalette.textTertiary.opacity(0.35)))
                    .markdownTableBackgroundStyle(
                        .alternatingRows(Color.clear, AppPalette.surfaceNested.opacity(0.4))
                    )
                    .markdownMargin(top: 0, bottom: 16)
            }
            .tableCell { configuration in
                configuration.label
                    .markdownTextStyle {
                        if configuration.row == 0 {
                            FontWeight(.semibold)
                        }
                        ForegroundColor(AppPalette.textPrimary)
                        BackgroundColor(Color.clear)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 13)
                    .relativeLineSpacing(.em(0.25))
            }
    }
}
