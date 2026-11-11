import Foundation
@testable import PetrelPLC
import XCTest

/// `AccountIdentifiers.validateDID` applies AT Protocol's rules for its two
/// supported DID methods ("Blessed DID Methods", https://atproto.com/specs/did),
/// the same rules as `DID.isValidAtprotoDID` in the `Petrel` module.
final class AccountIdentifiersTests: XCTestCase {
    func testValidateDIDWithValidPLC() throws {
        XCTAssertEqual(
            try AccountIdentifiers.validateDID("did:plc:z72i7hdynmk6r22z27h6tvur"),
            "did:plc:z72i7hdynmk6r22z27h6tvur"
        )
    }

    func testValidateDIDRejectsMalformedPLC() {
        for invalid in [
            "did:plc:z72i7hdynmk6r22z27h6tvu", // 23 characters
            "did:plc:z72i7hdynmk6r22z27h6tvurr", // 25 characters
            "did:plc:Z72I7HDYNMK6R22Z27H6TVUR", // upper case
            "did:plc:z72i7hdynmk6r22z27h6tv01", // 0 and 1 are not base32
            "did:plc:z72i7hdynmk6r22z27h6tvur:x",
            "DID:PLC:z72i7hdynmk6r22z27h6tvur",
        ] {
            XCTAssertThrowsError(try AccountIdentifiers.validateDID(invalid), invalid)
        }
    }

    func testValidateDIDWithValidWebDIDs() throws {
        for valid in [
            "did:web:example.com",
            "did:web:sub.domain.example.com",
            "did:web:Example.COM",
            "did:web:xn--bcher-kva.example.org",
            "did:web:a-b.example.io",
        ] {
            XCTAssertEqual(try AccountIdentifiers.validateDID(valid), valid)
        }
    }

    func testValidateDIDRejectsWebDIDsWithPathSegments() {
        // atproto allows hostname-level did:web only.
        for invalid in [
            "did:web:example.com:user:alice",
            "did:web:example.com:user",
            "did:web:example.com%3A443:user:Alice",
            "did:web:example.com:a%40b",
            "did:web:example.com:..:..:etc",
            "did:web:example.com:.:user",
            "did:web:example.com::user",
            "did:web:example.com:",
            "did:web:localhost:user",
        ] {
            XCTAssertThrowsError(try AccountIdentifiers.validateDID(invalid), invalid)
        }
    }

    func testValidateDIDAllowsAPortOnlyOnLocalhost() throws {
        for valid in ["did:web:localhost", "did:web:localhost%3A2583", "did:web:localhost%3a8080", "did:web:LOCALHOST%3A1"] {
            XCTAssertEqual(try AccountIdentifiers.validateDID(valid), valid)
        }
        for invalid in [
            "did:web:example.com%3A8080",
            "did:web:example.com%3A443",
            "did:web:localhost%3A0",
            "did:web:localhost%3A65536",
            "did:web:localhost%3Aabc",
            "did:web:localhost%3A",
            "did:web:localhost%3A443%3A80",
            "did:web:localhost%3A-1",
        ] {
            XCTAssertThrowsError(try AccountIdentifiers.validateDID(invalid), invalid)
        }
        // localhost is for development; production paths can refuse it.
        XCTAssertThrowsError(try AccountIdentifiers.validateDID("did:web:localhost", allowLocalhost: false))
        XCTAssertThrowsError(try AccountIdentifiers.validateDID("did:web:localhost%3A2583", allowLocalhost: false))
        XCTAssertNoThrow(try AccountIdentifiers.validateDID("did:web:example.com", allowLocalhost: false))
    }

    func testValidateDIDRejectsHostsThatAreNotHandleStyleDomains() {
        for invalid in [
            "did:web:1.2.3.4",
            "did:web:127.0.0.1",
            "did:web:example.123",
            "did:web:example.123a", // the final label must start with a letter
            "did:web:example", // a single label
            "did:web:-example.com",
            "did:web:example-.com",
            "did:web:exa_mple.com",
            "did:web:example..com",
            "did:web:.example.com",
            "did:web:example.com.",
            "did:web:" + String(repeating: "a", count: 64) + ".com",
            "did:web:",
            "did:web:example.com%2Fpath",
            "did:web:[::1]",
        ] {
            XCTAssertThrowsError(try AccountIdentifiers.validateDID(invalid), invalid)
        }
    }

    func testValidateDIDRejectsReservedTopLevelDomains() {
        for tld in AccountIdentifiers.disallowedTLDs {
            XCTAssertThrowsError(try AccountIdentifiers.validateDID("did:web:host\(tld)"), tld)
        }
        XCTAssertEqual(AccountIdentifiers.disallowedTLDs.count, 8)
        for invalid in ["did:web:laptop.local", "did:web:service.onion", "did:web:a.b.internal", "did:web:Example.LOCAL"] {
            XCTAssertThrowsError(try AccountIdentifiers.validateDID(invalid), invalid)
        }
        // `.test` is reserved for testing and is not on the list.
        XCTAssertNoThrow(try AccountIdentifiers.validateDID("did:web:pds.test"))
    }

    func testValidateDIDRejectsOtherMethodsAndNonDIDs() {
        for invalid in [
            "did:key:zQ3shqwJEJyMBsBXCWyCBpUBMqxcon9oHB7mCvx4sSpMdLJwc",
            "did:example:123",
            "did:plc",
            "did:",
            "",
            "example.com",
            "did:web:example.com ",
            "did:web:exämple.com",
            "did:web:" + String(repeating: "a.", count: 1_100) + "com",
        ] {
            XCTAssertThrowsError(try AccountIdentifiers.validateDID(invalid), invalid)
        }
    }

    func testCanonicalHandle() throws {
        XCTAssertEqual(try AccountIdentifiers.canonicalHandle("Alice.Example.COM"), "alice.example.com")
        for invalid in ["alice", "alice.123", "-a.example.com", "a..example.com", "alice@example.com", ""] {
            XCTAssertThrowsError(try AccountIdentifiers.canonicalHandle(invalid), invalid)
        }
    }
}
