import SwiftUI

struct SettingsContent: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        Form {
            Section("About") {
                LabeledContent("Version", value: appVersion)
                LabeledContent("Build", value: build)
                Text("Phathom keeps your library on this device only.")
                    .font(.footnote)
                    .foregroundStyle(AppPalette.textSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppPalette.background)
        .tint(AppPalette.accent)
        .foregroundStyle(AppPalette.textPrimary)
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
