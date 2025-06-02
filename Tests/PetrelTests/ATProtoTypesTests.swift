import Foundation
@testable import Petrel
import Testing

@Suite("ATProto Types Tests")
struct ATProtoTypesTests {
    @Suite("DID Tests")
    struct DIDTests {
        @Test("Valid DID creation")
        func validDIDCreation() throws {
            #expect(try DID(didString: "did:plc:abcd1234").description == "did:plc:abcd1234")
            #expect(try DID(didString: "did:web:example.com").description == "did:web:example.com")
            #expect(!try DID(didString: "did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK").description.isEmpty)
        }

        @Test("Invalid DID creation")
        func invalidDIDCreation() {
            #expect(throws: (any Error).self) {
                try DID(didString: "")
            }
            #expect(throws: (any Error).self) {
                try DID(didString: "invalid")
            }
            #expect(throws: (any Error).self) {
                try DID(didString: "did:")
            }
            #expect(throws: (any Error).self) {
                try DID(didString: "di:plc:test")
            }
            #expect(throws: (any Error).self) {
                try DID(didString: "did::test")
            }
        }

        @Test("DID bounds checking")
        func dIDBoundsChecking() {
            #expect(throws: (any Error).self) {
                try DID(didString: "did") // Too short for dropFirst(4)
            }
            #expect(throws: (any Error).self) {
                try DID(didString: "di")
            }
            #expect(throws: (any Error).self) {
                try DID(didString: "d")
            }
        }
    }

    @Suite("ATProtocolURI Tests")
    struct ATProtocolURITests {
        @Test("Valid URI creation")
        func validURICreation() throws {
            let uri = try ATProtocolURI(uriString: "at://did:plc:test/app.bsky.feed.post/abc123")
            #expect(uri.repo == "did:plc:test")
            #expect(uri.collection == "app.bsky.feed.post")
            #expect(uri.rkey == "abc123")
        }

        @Test("URI without rkey")
        func uRIWithoutRkey() throws {
            let uri = try ATProtocolURI(uriString: "at://did:plc:test/app.bsky.feed.post")
            #expect(uri.repo == "did:plc:test")
            #expect(uri.collection == "app.bsky.feed.post")
            #expect(uri.rkey == nil)
        }

        @Test("Invalid URI creation")
        func invalidURICreation() {
            #expect(throws: (any Error).self) {
                try ATProtocolURI(uriString: "")
            }
            #expect(throws: (any Error).self) {
                try ATProtocolURI(uriString: "invalid")
            }
            #expect(throws: (any Error).self) {
                try ATProtocolURI(uriString: "at://") // Too short
            }
        }

        @Test("URI bounds checking")
        func uRIBoundsChecking() {
            #expect(throws: (any Error).self) {
                try ATProtocolURI(uriString: "at://") // Too short for dropFirst(5)
            }
            #expect(throws: (any Error).self) {
                try ATProtocolURI(uriString: "at:/") // Too short
            }
        }
    }

    @Suite("Handle Tests")
    struct HandleTests {
        @Test("Valid handle creation")
        func validHandleCreation() throws {
            #expect(try Handle(handleString: "alice.bsky.social").description == "alice.bsky.social")
            #expect(try Handle(handleString: "test.example.com").description == "test.example.com")
            #expect(try Handle(handleString: "user.localhost").description == "user.localhost")
        }

        @Test("Invalid handle creation")
        func invalidHandleCreation() {
            #expect(throws: (any Error).self) {
                try Handle(handleString: "")
            }
            #expect(throws: (any Error).self) {
                try Handle(handleString: ".invalid")
            }
            #expect(throws: (any Error).self) {
                try Handle(handleString: "invalid.")
            }
            #expect(throws: (any Error).self) {
                try Handle(handleString: "no-dots")
            }
            #expect(throws: (any Error).self) {
                try Handle(handleString: "has spaces.com")
            }
        }

        @Test("Handle length limits")
        func handleLengthLimits() {
            let longHandle = String(repeating: "a", count: 254) + ".com"
            #expect(throws: (any Error).self) {
                try Handle(handleString: longHandle)
            }

            let validLengthHandle = String(repeating: "a", count: 240) + ".com"
            #expect(throws: Never.self) {
                try Handle(handleString: validLengthHandle)
            }
        }
    }

    @Suite("NSID Tests")
    struct NSIDTests {
        @Test("Valid NSID creation")
        func validNSIDCreation() throws {
            #expect(try NSID(nsidString: "app.bsky.feed.post").description == "app.bsky.feed.post")
            #expect(try NSID(nsidString: "com.example.test").description == "com.example.test")
        }

        @Test("Invalid NSID creation")
        func invalidNSIDCreation() {
            #expect(throws: (any Error).self) {
                try NSID(nsidString: "")
            }
            #expect(throws: (any Error).self) {
                try NSID(nsidString: "invalid")
            }
            #expect(throws: (any Error).self) {
                try NSID(nsidString: "app.bsky.")
            }
            #expect(throws: (any Error).self) {
                try NSID(nsidString: ".invalid")
            }
        }

        @Test("NSID length limits")
        func nSIDLengthLimits() {
            let longNSID = String(repeating: "a", count: 585)
            #expect(throws: (any Error).self) {
                try NSID(nsidString: longNSID)
            }

            let validLengthNSID = "app.bsky." + String(repeating: "a", count: 500)
            #expect(throws: Never.self) {
                try NSID(nsidString: validLengthNSID)
            }
        }
    }

    @Suite("RecordKey Tests")
    struct RecordKeyTests {
        @Test("Valid RecordKey creation")
        func validRecordKeyCreation() throws {
            #expect(try RecordKey(keyString: "abc123").description == "abc123")
            #expect(try RecordKey(keyString: "test-key_123").description == "test-key_123")
            #expect(try RecordKey(keyString: "2024-01-01").description == "2024-01-01")
        }

        @Test("Invalid RecordKey creation")
        func invalidRecordKeyCreation() {
            #expect(throws: (any Error).self) {
                try RecordKey(keyString: "")
            }
            #expect(throws: (any Error).self) {
                try RecordKey(keyString: "has spaces")
            }
            #expect(throws: (any Error).self) {
                try RecordKey(keyString: "has/slash")
            }
        }

        @Test("RecordKey length limits")
        func recordKeyLengthLimits() {
            let longKey = String(repeating: "a", count: 513)
            #expect(throws: (any Error).self) {
                try RecordKey(keyString: longKey)
            }

            let validLengthKey = String(repeating: "a", count: 512)
            #expect(throws: Never.self) {
                try RecordKey(keyString: validLengthKey)
            }
        }

        @Test("RecordKey fallback validation")
        func recordKeyFallbackValidation() {
            // Test that the fallback validation works when regex fails
            #expect(throws: Never.self) {
                try RecordKey(keyString: "valid123")
            }
            #expect(throws: Never.self) {
                try RecordKey(keyString: "test_key")
            }
            #expect(throws: Never.self) {
                try RecordKey(keyString: "2024-01-01")
            }
        }
    }
}
