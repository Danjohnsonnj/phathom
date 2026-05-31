import PhathomCore
import SwiftData
import SwiftUI

struct HighlightNoteEditSheet: View {
    @Bindable var highlight: Highlight
    var modelContext: ModelContext
    var onDismiss: () -> Void

    @State private var noteDraft: String = ""
    @State private var persistenceError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HairlineHighlightRow(
                        quotedText: highlight.quotedText,
                        userNote: highlight.userNote,
                        showsBottomHairline: false,
                        onTap: {}
                    )
                    .allowsHitTesting(false)

                    TextEditor(text: $noteDraft)
                        .frame(minHeight: 140)
                        .padding(10)
                        .scrollContentBackground(.hidden)
                        .background(AppPalette.surfaceNested)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(AppPalette.textPrimary)

                    if let persistenceError {
                        Text(persistenceError)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        persistenceError = nil
                        let t = noteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        highlight.userNote = t.isEmpty ? nil : String(t.prefix(10_000))
                        if let err = DetailModelSave.save(modelContext, operation: "saveHighlightNote") {
                            persistenceError = err
                        } else {
                            LibraryContentChangeNotifier.postLibraryContentDidChange()
                            onDismiss()
                        }
                    } label: {
                        Text("Save")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppPalette.floralWhite)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppPalette.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        persistenceError = nil
                        highlight.userNote = nil
                        if let err = DetailModelSave.save(modelContext, operation: "deleteHighlightNote") {
                            persistenceError = err
                        } else {
                            LibraryContentChangeNotifier.postLibraryContentDidChange()
                            onDismiss()
                        }
                    } label: {
                        Text("Delete note")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppPalette.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppPalette.surfaceNested)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button(role: .destructive) {
                        persistenceError = nil
                        modelContext.delete(highlight)
                        if let err = DetailModelSave.save(modelContext, operation: "removeHighlight") {
                            persistenceError = err
                        } else {
                            LibraryContentChangeNotifier.postLibraryContentDidChange()
                            onDismiss()
                        }
                    } label: {
                        Text("Remove highlight")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.vertical, 16)
            }
            .background(AppPalette.background)
            .navigationTitle("Highlight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onDismiss() }
                }
            }
            .onAppear { noteDraft = highlight.userNote ?? "" }
        }
    }
}
