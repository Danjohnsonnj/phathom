import Foundation
import SwiftData

enum DetailModelSave {
    @discardableResult
    static func save(_ context: ModelContext, operation: String) -> String? {
        do {
            try context.save()
            return nil
        } catch {
            #if DEBUG
            assertionFailure("[DetailModelSave] \(operation): \(error)")
            #endif
            print("[DetailModelSave] \(operation) failed: \(error.localizedDescription)")
            return error.localizedDescription
        }
    }
}
