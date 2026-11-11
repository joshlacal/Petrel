@testable import Petrel
import XCTest

/// The DNS TXT method of the handle specification: only values that start with `did=` count,
/// and the remainder must be a DID.
final class DIDResolutionTXTRecordTests: XCTestCase {
    func testAcceptsDIDEqualsTXTRecord() {
        XCTAssertEqual(IdentityResolver.didsInTXTRecords(["did=did:plc:alice"]), ["did:plc:alice"])
    }

    func testIgnoresRecordWithoutDIDEqualsPrefix() {
        XCTAssertEqual(IdentityResolver.didsInTXTRecords(["did:plc:alice"]), [])
        XCTAssertEqual(IdentityResolver.didsInTXTRecords(["v=spf1 -all"]), [])
        XCTAssertEqual(IdentityResolver.didsInTXTRecords([" did=did:plc:alice"]), [])
        XCTAssertEqual(IdentityResolver.didsInTXTRecords(["DID=did:plc:alice"]), [])
    }

    func testDoesNotRepairMalformedValues() {
        XCTAssertEqual(IdentityResolver.didsInTXTRecords(["did=did:did:plc:alice"]), ["did:did:plc:alice"])
        XCTAssertEqual(IdentityResolver.didsInTXTRecords(["did=plc:alice"]), [])
        XCTAssertEqual(IdentityResolver.didsInTXTRecords(["did="]), [])
        XCTAssertEqual(IdentityResolver.didsInTXTRecords(["did=did:plc:alice "]), [])
        XCTAssertEqual(IdentityResolver.didsInTXTRecords(["did=did:plc:alice\n"]), [])
        XCTAssertEqual(IdentityResolver.didsInTXTRecords(["did=did:plc:alice#fragment"]), [])
    }

    func testKeepsUnrelatedRecordsOutOfTheResult() {
        XCTAssertEqual(
            IdentityResolver.didsInTXTRecords(["v=spf1 -all", "did=did:plc:alice", "google-site-verification=abc"]),
            ["did:plc:alice"]
        )
    }

    func testRepeatedRecordForTheSameDIDIsOneResult() {
        XCTAssertEqual(
            IdentityResolver.didsInTXTRecords(["did=did:plc:alice", "did=did:plc:alice"]),
            ["did:plc:alice"]
        )
    }

    #if canImport(Darwin)
        /// TXT RDATA as the system resolver hands it over: length-prefixed character-strings.
        func testSystemResolverJoinsCharacterStrings() {
            func join(_ bytes: [UInt8]) -> String {
                bytes.withUnsafeBytes { SystemDNSTXTQuery.joinedCharacterStrings($0) }
            }
            XCTAssertEqual(join([17] + Array("did=did:plc:alice".utf8)), "did=did:plc:alice")
            // A value split across two character-strings is one value.
            XCTAssertEqual(join([4] + Array("did=".utf8) + [13] + Array("did:plc:alice".utf8)), "did=did:plc:alice")
            XCTAssertEqual(join([]), "")
            XCTAssertEqual(join([0]), "")
            // A length that runs past the record is clamped, never read out of bounds.
            XCTAssertEqual(join([200] + Array("did=".utf8)), "did=")
        }
    #endif

    func testRecordsForDifferentDIDsAreAllReported() {
        XCTAssertEqual(
            IdentityResolver.didsInTXTRecords(["did=did:plc:alice", "did=did:web:example.com"]),
            ["did:plc:alice", "did:web:example.com"]
        )
    }
}
