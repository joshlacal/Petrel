import Foundation
@testable import Petrel
import Testing

@Suite("ImageMetadataStripper Tests")
struct ImageMetadataStripperTests {
    @Test("stripMetadata fails closed on unsupported platforms / invalid data")
    func stripMetadataFailsClosed() {
        #if os(Linux)
        // On Linux, ImageIO / metadata stripping is unavailable and must return nil (fail closed)
        let dummyJPEG = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01])
        let stripped = ImageMetadataStripper.stripMetadata(from: dummyJPEG)
        #expect(stripped == nil)
        #else
        // On macOS/iOS, stripping invalid image data should also fail closed and return nil
        let invalidData = Data([0x00, 0x01, 0x02, 0x03])
        let stripped = ImageMetadataStripper.stripMetadata(from: invalidData)
        #expect(stripped == nil)
        #endif
    }

    @Test("NetworkError contains metadataStrippingFailed case")
    func metadataStrippingFailedError() {
        let error = NetworkError.metadataStrippingFailed
        #expect(error.localizedDescription.contains("metadata"))
        #expect(error.failureReason?.contains("Metadata") == true)
        #expect(error.recoverySuggestion?.contains("metadata") == true)
    }
}
