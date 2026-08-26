import XCTest

@testable import PetrelJetstream

final class ZstdTests: XCTestCase {
  func testRoundTrip() throws {
    let payload = Data((0..<10_000).map { UInt8(truncatingIfNeeded: $0 &* 31) })
    let compressed = try JetstreamZstd.compress(payload)
    XCTAssertLessThan(compressed.count, payload.count)
    let decompressed = try JetstreamZstd.decompress(compressed)
    XCTAssertEqual(decompressed, payload)
  }

  func testEmptyFrameRejected() {
    XCTAssertThrowsError(try JetstreamZstd.decompress(Data()))
  }

  func testGarbageFrameRejected() {
    XCTAssertThrowsError(try JetstreamZstd.decompress(Data([0xDE, 0xAD, 0xBE, 0xEF, 0x00])))
  }

  func testDeclaredSizeGuard() throws {
    let payload = Data(repeating: 0x41, count: 4096)
    let compressed = try JetstreamZstd.compress(payload)
    XCTAssertThrowsError(try JetstreamZstd.decompress(compressed, maxDecompressedSize: 16)) { error in
      guard case JetstreamZstdError.frameTooLarge = error as! JetstreamZstdError else {
        return XCTFail("expected frameTooLarge, got \(error)")
      }
    }
  }

  func testDictionaryRoundTrip() throws {
    // A raw-content dictionary: zstd treats any blob as a valid raw dictionary,
    // Structured-dictionary header: magic 0xEC30A437 LE + dictID; zstd reads
    // the embedded ID straight from the header.
    var dictionary = Data([0x37, 0xA4, 0x30, 0xEC])  // dictionary magic, LE
    dictionary.append(contentsOf: [0x2A, 0x00, 0x00, 0x00])  // dictID = 42
    XCTAssertEqual(JetstreamZstd.dictionaryID(of: dictionary), 42)

    let rawDict = Data("app.bsky.feed.postapp.bsky.graph.followdid:plc:".utf8)
    let payload = Data("{\"$type\":\"message\",\"payload\":{\"collection\":\"app.bsky.feed.post\"}}".utf8)
    let compressed = try JetstreamZstd.compress(payload, dictionary: rawDict)
    let decoder = try JetstreamZstdDictionaryDecoder(dictionary: rawDict)
    XCTAssertEqual(try decoder.decompress(compressed), payload)
    // Wrong dictionary must fail, proving the dictionary actually participates.
    let wrongDecoder = try JetstreamZstdDictionaryDecoder(dictionary: Data("unrelated".utf8))
    XCTAssertThrowsError(try wrongDecoder.decompress(compressed))
  }
}
