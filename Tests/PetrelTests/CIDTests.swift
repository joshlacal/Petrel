import CryptoKit
import Foundation
@testable import Petrel
import SwiftCBOR
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

    // MARK: - CBOR Encoding Tests

    @Test("CID CBOR encoding returns string")
    func cidCBOREncoding() throws {
        let testData = "Hello, AT Protocol!".data(using: .utf8)!
        let cid = CID.fromDAGCBOR(testData)

        // Test how CID encodes to CBOR value
        let cborValue = try cid.toCBORValue()
        print("✓ CID.toCBORValue() returns: \(type(of: cborValue)) = \(cborValue)")

        // Should return string representation (current implementation)
        #expect(cborValue is String, "CID.toCBORValue() should return String")
        if let cidString = cborValue as? String {
            #expect(cidString == cid.string, "Should return CID string representation")
        }
    }

    @Test("StrongRef CBOR encoding")
    func strongRefCBOREncoding() throws {
        let testCID = CID.fromDAGCBOR("test".data(using: .utf8)!)
        let testURI = try ATProtocolURI(uriString: "at://did:plc:test/app.bsky.feed.post/123")

        let strongRef = ComAtprotoRepoStrongRef(uri: testURI, cid: testCID)

        // Test how StrongRef encodes to CBOR
        let cborValue = try strongRef.toCBORValue()
        print("✓ StrongRef.toCBORValue() returns: \(type(of: cborValue))")

        #expect(cborValue is OrderedCBORMap, "StrongRef should return OrderedCBORMap")

        if let orderedMap = cborValue as? OrderedCBORMap {
            print("✓ StrongRef entries:")
            for (key, value) in orderedMap.entries {
                print("  - \(key): \(type(of: value)) = \(value)")
            }
        }

        // Encode the StrongRef to CBOR data
        let cborData = try strongRef.encodedDAGCBOR()
        print("✓ StrongRef CBOR length: \(cborData.count) bytes")
        print("✓ StrongRef CBOR hex: \(cborData.map { String(format: "%02x", $0) }.joined())")
    }

    @Test("Post with reply CBOR encoding")
    func postWithReplyCBOREncoding() throws {
        // Create a parent post
        let parentCID = CID.fromDAGCBOR("parent post".data(using: .utf8)!)
        let parentURI = try ATProtocolURI(uriString: "at://did:plc:parent/app.bsky.feed.post/parent123")

        // Create reply reference
        let parentRef = ComAtprotoRepoStrongRef(uri: parentURI, cid: parentCID)
        let replyRef = AppBskyFeedPost.ReplyRef(root: parentRef, parent: parentRef)

        // Create reply post
        let replyPost = AppBskyFeedPost(
            text: "This is a reply!",
            entities: nil,
            facets: nil,
            reply: replyRef,
            embed: nil,
            langs: nil,
            labels: nil,
            tags: nil,
            createdAt: ATProtocolDate(date: Date(timeIntervalSince1970: 1_640_995_200)) // Fixed timestamp
        )

        // Test CBOR encoding
        let cborData = try replyPost.encodedDAGCBOR()
        let calculatedCID = CID.fromDAGCBOR(cborData)

        print("✓ Reply post CBOR length: \(cborData.count) bytes")
        print("✓ Reply post CID: \(calculatedCID.string)")
        print("✓ Parent CID in reply: \(parentCID.string)")

        // Decode and examine the CBOR structure
        let decodedCBOR = try CBOR.decode([UInt8](cborData))
        if let cborItem = decodedCBOR {
            let decodedValue = try DAGCBOR.decodeCBORItem(cborItem)
            print("✓ Decoded CBOR structure:")
            printCBORStructure(decodedValue, indent: "  ")
        }

        // The CBOR should be deterministic
        let cborData2 = try replyPost.encodedDAGCBOR()
        let calculatedCID2 = CID.fromDAGCBOR(cborData2)

        #expect(cborData == cborData2, "CBOR encoding should be deterministic")
        #expect(calculatedCID == calculatedCID2, "CID should be deterministic")
    }

    @Test("ATProtoLink vs CID string encoding")
    func atProtoLinkVsCIDString() throws {
        let testCID = CID.fromDAGCBOR("test".data(using: .utf8)!)

        // Test ATProtoLink encoding (should use Tag 42)
        let atprotoLink = ATProtoLink(cid: testCID)
        let linkCBORValue = try atprotoLink.toCBORValue()
        print("✓ ATProtoLink.toCBORValue() returns: \(type(of: linkCBORValue))")

        // Test direct CID encoding (should be string)
        let cidCBORValue = try testCID.toCBORValue()
        print("✓ CID.toCBORValue() returns: \(type(of: cidCBORValue))")

        // They should be different
        #expect(
            type(of: linkCBORValue) != type(of: cidCBORValue),
            "ATProtoLink and CID should encode differently"
        )

        // Test full CBOR encoding
        let linkCBORData = try atprotoLink.encodedDAGCBOR()
        print("✓ ATProtoLink CBOR length: \(linkCBORData.count) bytes")
        print("✓ ATProtoLink CBOR hex: \(linkCBORData.map { String(format: "%02x", $0) }.joined())")

        // Decode and check for Tag 42
        let decodedCBOR = try CBOR.decode([UInt8](linkCBORData))
        if let cborItem = decodedCBOR {
            let hasTag42 = checkForTag42(cborItem)
            #expect(hasTag42, "ATProtoLink should contain CBOR Tag 42")
        }
    }

    @Test("CBOR canonical encoding consistency")
    func cborCanonicalEncoding() throws {
        // Test that our CBOR encoding is canonical/deterministic
        let post = AppBskyFeedPost(
            text: "Test post",
            entities: nil,
            facets: nil,
            reply: nil,
            embed: nil,
            langs: nil,
            labels: nil,
            tags: nil,
            createdAt: ATProtocolDate(date: Date(timeIntervalSince1970: 1_640_995_200)) // Fixed timestamp
        )

        let cbor1 = try post.encodedDAGCBOR()
        let cbor2 = try post.encodedDAGCBOR()

        #expect(cbor1 == cbor2, "CBOR encoding should be deterministic")

        let cid1 = CID.fromDAGCBOR(cbor1)
        let cid2 = CID.fromDAGCBOR(cbor2)

        #expect(cid1 == cid2, "CIDs should be identical for same data")

        print("✓ CBOR canonical encoding test passed")
        print("  - CBOR length: \(cbor1.count) bytes")
        print("  - CID: \(cid1.string)")
    }

    @Test("CID format compliance")
    func cidFormatCompliance() throws {
        let testData = "Hello, AT Protocol!".data(using: .utf8)!
        let cid = CID.fromDAGCBOR(testData)

        // Verify CID format compliance with AT Protocol spec
        #expect(cid.string.hasPrefix("b"), "CID should start with 'b' prefix (base32)")
        #expect(cid.codec == .dagCBOR, "Post CID should use dag-cbor codec (0x71)")
        #expect(cid.multihash.algorithm == Multihash.sha256Code, "Should use SHA-256 (0x12)")
        #expect(cid.multihash.length == Multihash.sha256Length, "Should use 32-byte hash")

        // Test blob CID
        let blobCID = CID.fromBlob(testData)
        #expect(blobCID.codec == .raw, "Blob CID should use raw codec (0x55)")

        print("✓ CID format compliance verified")
        print("  - DAG-CBOR CID: \(cid.string)")
        print("  - Raw CID: \(blobCID.string)")
    }

    // MARK: - Helper Methods

    private func printCBORStructure(_ value: Any, indent: String) {
        switch value {
        case let dict as [String: Any]:
            print("\(indent)Dictionary:")
            for (key, val) in dict.sorted(by: { $0.key < $1.key }) {
                print("\(indent)  \(key):")
                printCBORStructure(val, indent: indent + "    ")
            }
        case let array as [Any]:
            print("\(indent)Array (\(array.count) items):")
            for (index, item) in array.enumerated() {
                print("\(indent)  [\(index)]:")
                printCBORStructure(item, indent: indent + "    ")
            }
        case let cid as CID:
            print("\(indent)CID: \(cid.string)")
        case let string as String:
            print("\(indent)String: \"\(string)\"")
        case let number as NSNumber:
            print("\(indent)Number: \(number)")
        case let data as Data:
            print("\(indent)Data: \(data.count) bytes")
        default:
            print("\(indent)\(type(of: value)): \(value)")
        }
    }

    private func checkForTag42(_ cbor: CBOR) -> Bool {
        switch cbor {
        case let .tagged(tag, value):
            if tag.rawValue == 42 {
                print("✓ Found CBOR Tag 42 (CID link)")
                print("  - Tag value type: \(value)")
                return true
            } else {
                print("✓ Found CBOR Tag \(tag.rawValue)")
            }
        case let .map(dict):
            for (_, value) in dict {
                if checkForTag42(value) {
                    return true
                }
            }
        case let .array(array):
            for item in array {
                if checkForTag42(item) {
                    return true
                }
            }
        default:
            break
        }
        return false
    }
}
