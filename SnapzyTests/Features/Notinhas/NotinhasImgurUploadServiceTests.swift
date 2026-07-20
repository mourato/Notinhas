import AppKit
@testable import Snapzy
import XCTest

final class NotinhasImgurUploadServiceTests: XCTestCase {
  func testUploadRejectsMissingClientID() async {
    let service = NotinhasImgurUploadService()
    let image = NSImage(size: NSSize(width: 10, height: 10))

    do {
      _ = try await service.upload(image: image, clientID: " ")
      XCTFail("Expected missing client ID error")
    } catch let error as NotinhasImgurUploadError {
      XCTAssertEqual(error, .missingClientID)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }
}
