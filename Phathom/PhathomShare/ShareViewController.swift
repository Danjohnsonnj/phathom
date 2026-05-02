import PhathomCore
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let root = ShareRootView(extensionContext: extensionContext)
        let host = UIHostingController(rootView: root)
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)
    }
}

private struct ShareRootView: View {
    var extensionContext: NSExtensionContext?
    @State private var message = "Saving…"
    @State private var isError = false

    var body: some View {
        VStack(spacing: 16) {
            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding()
            if isError {
                Button("Close") { finish() }
            }
        }
        .task {
            await saveSharedItems()
        }
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    private func saveSharedItems() async {
        guard let ctx = extensionContext else {
            message = "Missing share context."
            isError = true
            return
        }

        var sharedURL: URL?
        var plainText: String?
        var imageJPEGData: Data?

        for item in ctx.inputItems {
            guard let extItem = item as? NSExtensionItem else { continue }
            guard let attachments = extItem.attachments else { continue }
            for provider in attachments {
                if sharedURL == nil, provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    do {
                        let obj = try await provider.loadItem(forTypeIdentifier: UTType.url.identifier)
                        if let u = obj as? URL {
                            sharedURL = u
                        } else if let data = obj as? Data, let u = URL(dataRepresentation: data, relativeTo: nil) {
                            sharedURL = u
                        }
                    } catch {
                        continue
                    }
                }
                if plainText == nil, provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    do {
                        let obj = try await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier)
                        if let s = obj as? String {
                            plainText = s
                        } else if let data = obj as? Data, let s = String(data: data, encoding: .utf8) {
                            plainText = s
                        }
                    } catch {
                        continue
                    }
                }
                if imageJPEGData == nil, provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    do {
                        let obj = try await provider.loadItem(forTypeIdentifier: UTType.image.identifier)
                        if let img = obj as? UIImage {
                            imageJPEGData = MediaImageEncoding.normalizedJPEG(from: img)
                        } else if let url = obj as? URL {
                            let data = try Data(contentsOf: url)
                            imageJPEGData = MediaImageEncoding.normalizedJPEG(from: data) ?? data
                        } else if let data = obj as? Data {
                            imageJPEGData = MediaImageEncoding.normalizedJPEG(from: data) ?? data
                        }
                    } catch {
                        continue
                    }
                }
            }
        }

        let hasText = plainText.map { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? false
        let hasImage = imageJPEGData.map { !$0.isEmpty } ?? false
        guard sharedURL != nil || hasText || hasImage else {
            await MainActor.run {
                message = "Nothing to save (need a link, text, or image)."
                isError = true
            }
            return
        }

        do {
            let container = try PhathomModelContainer.makeShared()
            let modelCtx = ModelContext(container)
            try ShareCapture.insertFromShare(
                context: modelCtx,
                sharedURL: sharedURL,
                plainText: plainText,
                imageJPEGData: imageJPEGData,
                urlTextPrecedence: .urlOnly
            )
            PhathomIPC.notifyStoreChanged()
            await MainActor.run {
                message = "Saved to Phathom."
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    finish()
                }
            }
        } catch let shareError as ShareCaptureError {
            await MainActor.run {
                message = shareError.localizedDescription
                isError = true
            }
        } catch {
            await MainActor.run {
                message = error.localizedDescription
                isError = true
            }
        }
    }
}
