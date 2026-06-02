#if os(iOS)
import PhathomCore
import UIKit
import XCTest

final class MediaImageEncodingTests: XCTestCase {
    func testLibraryStorageJPEGSmallerThanDefaultNormalization() throws {
        let size = CGSize(width: 2400, height: 1800)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }

        let full = try XCTUnwrap(MediaImageEncoding.normalizedJPEG(from: image))
        let library = try XCTUnwrap(MediaImageEncoding.normalizedJPEGForLibraryStorage(from: image))

        XCTAssertLessThan(
            library.count,
            full.count,
            "library storage profile should produce a smaller on-disk JPEG than default 1600/0.82"
        )
    }
}
#endif
