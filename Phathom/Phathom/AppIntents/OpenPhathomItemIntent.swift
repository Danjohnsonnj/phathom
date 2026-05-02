import PhathomCore
import AppIntents
import Foundation

struct OpenPhathomItemIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Phathom Item"

    @Parameter(title: "Item ID")
    var itemID: String

    init() {}

    init(itemID: String) {
        self.itemID = itemID
    }

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(
                name: .openPhathomItem,
                object: nil,
                userInfo: ["itemID": itemID]
            )
        }
        return .result()
    }
}
