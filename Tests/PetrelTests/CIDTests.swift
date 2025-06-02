import Foundation
@testable import Petrel
import Testing

@Suite("CID Tests")
struct CIDTests {
    @Test("CID should validate known good CIDs")
    func testValidCIDs() throws {
        // Test with known valid CID strings from the AT Protocol
        let validCIDs = [
            "bafyreigcxd76a5xqjzw2l6fq3u7d26hjtybdslqj2kxlzpvfyrvhycbr2a",
            "bafyreif7h6gxlc6kpxthfclr3vkqffn4yixoqmmqr7m2kq4xfacgjnlvhm",
            "bafyreid7qjxf7f4pszgnjj6x7v7dcxpehbxvqfxvlazmnhp26g5qbgzxqe",
        ]

        for cidString in validCIDs {
            let cid = try CID.parse(cidString)
            #expect(cid.description == cidString)
        }
    }

    @Test("CID should reject invalid formats")
    func testInvalidCIDs() {
        let invalidCIDs = [
            "",
            "invalid",
            "bafyreid", // Too short
            "not-a-cid-at-all",
            "bafyreigcxd76a5xqjzw2l6fq3u7d26hjtybdslqj2kxlzpvfyrvhycbr2!", // Invalid character
            "mafyreigcxd76a5xqjzw2l6fq3u7d26hjtybdslqj2kxlzpvfyrvhycbr2a", // Wrong prefix
        ]

        for cidString in invalidCIDs {
            #expect(throws: (any Error).self) {
                try CID.parse(cidString)
            }
        }
    }

    @Test("CID should handle base32 encoding correctly")
    func cIDBase32Handling() throws {
        // CIDs use base32 encoding with specific alphabet
        let validBase32CID = "bafyreigcxd76a5xqjzw2l6fq3u7d26hjtybdslqj2kxlzpvfyrvhycbr2a"
        let cid = try CID.parse(validBase32CID)
        #expect(cid.description == validBase32CID)

        // Should reject CIDs with invalid base32 characters
        let invalidBase32CID = "bafyreigcxd76a5xqjzw2l6fq3u7d26hjtybdslqj2kxlzpvfyrvhycbr2@"
        #expect(throws: (any Error).self) {
            try CID.parse(invalidBase32CID)
        }
    }

    @Test("CID equality should work correctly")
    func cIDEquality() throws {
        let cidString = "bafyreigcxd76a5xqjzw2l6fq3u7d26hjtybdslqj2kxlzpvfyrvhycbr2a"
        let cid1 = try CID.parse(cidString)
        let cid2 = try CID.parse(cidString)

        #expect(cid1 == cid2)
        #expect(cid1.description == cid2.description)

        let differentCID = try CID.parse("bafyreif7h6gxlc6kpxthfclr3vkqffn4yixoqmmqr7m2kq4xfacgjnlvhm")
        #expect(cid1 != differentCID)
    }

    @Test("CID should handle various lengths")
    func cIDLengths() throws {
        // CIDs can have different lengths depending on the hash used
        let shortCID = "bafyreigcxd76a5xqjzw2l6fq3u7d26hjtybdslqj2kxlzpvfyrvhycbr2a"
        let longCID = "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"

        let cid1 = try CID.parse(shortCID)
        let cid2 = try CID.parse(longCID)

        #expect(cid1.description == shortCID)
        #expect(cid2.description == longCID)
    }

    @Test("CID should be hashable")
    func cIDHashable() throws {
        let cidString = "bafyreigcxd76a5xqjzw2l6fq3u7d26hjtybdslqj2kxlzpvfyrvhycbr2a"
        let cid = try CID.parse(cidString)

        var cidSet: Set<CID> = []
        cidSet.insert(cid)
        #expect(cidSet.contains(cid))
        #expect(cidSet.count == 1)

        // Adding the same CID again shouldn't increase count
        cidSet.insert(cid)
        #expect(cidSet.count == 1)
    }

    @Test("CID creation from data")
    func cIDFromData() {
        let testData = "Hello, World!".data(using: .utf8)!

        // Test creating CID from DAG-CBOR data
        let dagCBORCID = CID.fromDAGCBOR(testData)
        #expect(dagCBORCID.codec == .dagCBOR)

        // Test creating CID from blob data
        let blobCID = CID.fromBlob(testData)
        #expect(blobCID.codec == .raw)

        // They should be different since they use different codecs
        #expect(dagCBORCID != blobCID)
    }
}
