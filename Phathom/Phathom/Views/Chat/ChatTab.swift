import SwiftUI

struct ChatTab: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Deep Dive coming in a future update")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Chat")
        }
    }
}
