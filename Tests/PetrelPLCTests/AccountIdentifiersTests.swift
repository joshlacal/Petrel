import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
import PetrelCore
import PetrelCrypto
@testable import PetrelPLC
import XCTest

final class AccountIdentifiersTests: XCTestCase {
    func testValidateDIDWithValidPLC() throws {
        XCTAssertEqual(
            try AccountIdentifiers.validateDID("did:plc:z72i7hdynmk6r22z27h6tvur"),
            "did:plc:z72i7hdynmk6r22z27h6tvur"
        )
    }

    func testValidateDIDWithValidWebDIDs() throws {
        XCTAssertEqual(
            try AccountIdentifiers.validateDID("did:web:example.com"),
            "did:web:example.com"
        )
        // P1: DID-Core percent-encoded port format
        XCTAssertEqual(
            try AccountIdentifiers.validateDID("did:web:example.com%3A443:user:Alice"),
            "did:web:example.com%3A443:user:Alice"
        )
        XCTAssertEqual(
            try AccountIdentifiers.validateDID("did:web:example.com%3A8080"),
            "did:web:example.com%3A8080"
        )
    }

    func testValidateDIDRejectsInvalidWebDIDPorts() throws {
        for invalid in [
            "did:web:example.com%3A0",
            "did:web:example.com%3A0443",
            "did:web:example.com%3A65536",
            "did:web:example.com%3Aabc",
            "did:web:example.com%3A443%3A80",
        ] {
            XCTAssertThrowsError(try AccountIdentifiers.validateDID(invalid), invalid)
        }
    }

    func testValidateDIDRejectsNumericFinalLabelIPLiterals() throws {
        // P1: numeric final-label guard
        for invalid in [
            "did:web:1.2.3.4",
            "did:web:127.0.0.1",
            "did:web:example.123",
        ] {
            XCTAssertThrowsError(try AccountIdentifiers.validateDID(invalid), invalid)
        }
        // Valid non-all-numeric final label
        XCTAssertEqual(
            try AccountIdentifiers.validateDID("did:web:example.123a"),
            "did:web:example.123a"
        )
    }

    func testValidateDIDRejectsPathTraversalInSegments() throws {
        // P1: path-traversal guard
        for invalid in [
            "did:web:example.com:..:..:etc",
            "did:web:example.com:.:user",
            "did:web:example.com::user",
        ] {
            XCTAssertThrowsError(try AccountIdentifiers.validateDID(invalid), invalid)
        }
    }

    func testValidateDIDRejectsUnescapedAtSymbolInPathSegments() throws {
        // P2: @ unescaped rejection
        XCTAssertThrowsError(try AccountIdentifiers.validateDID("did:web:example.com:a@b"))
        // Escaped @ (%40) is allowed
        XCTAssertEqual(
            try AccountIdentifiers.validateDID("did:web:example.com:a%40b"),
            "did:web:example.com:a%40b"
        )
    }
}
