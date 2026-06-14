@testable import Petrel
import XCTest

final class DIDResolutionTXTRecordTests: XCTestCase {
    func testAcceptsDirectDIDTXTRecord() {
        XCTAssertEqual(
            DIDResolutionService.didFromTXTRecord("did:plc:alice"),
            "did:plc:alice")
    }

    func testAcceptsDIDEqualsTXTRecord() {
        XCTAssertEqual(
            DIDResolutionService.didFromTXTRecord("did=did:plc:alice"),
            "did:plc:alice")
    }

    func testNormalizesDuplicatedDIDPrefixFromMalformedTXTRecord() {
        XCTAssertEqual(
            DIDResolutionService.didFromTXTRecord("did:did:plc:alice"),
            "did:plc:alice")
    }

    func testRejectsTXTRecordWithoutDIDValue() {
        XCTAssertNil(DIDResolutionService.didFromTXTRecord("v=spf1 -all"))
    }
}
