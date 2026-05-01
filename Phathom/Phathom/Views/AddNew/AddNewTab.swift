import SwiftUI

struct AddNewTab: View {
    @State private var title = ""
    @State private var urlString = ""
    @State private var showSaveNotice = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                    TextField("URL (optional)", text: $urlString)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                }

                Section {
                    Button("Save") {
                        showSaveNotice = true
                    }
                }
            }
            .navigationTitle("Add new")
            .alert("Not saved", isPresented: $showSaveNotice) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Capturing new items will be available in a future build.")
            }
        }
    }
}
