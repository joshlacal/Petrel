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
            let keyDID = try DID(didString: "did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK")
            #expect(!keyDID.description.isEmpty)
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
            let uri = try ATProtocolURI(uriString: "at://did:plc:test12345/app.bsky.feed.post/abc123")
            #expect(uri.authority == "did:plc:test12345")
            #expect(uri.collection == "app.bsky.feed.post")
            #expect(uri.recordKey == "abc123")

            let handleURI = try ATProtocolURI(uriString: "at://alice.bsky.social/app.bsky.feed.post/abc123")
            #expect(handleURI.authority == "alice.bsky.social")
            #expect(handleURI.collection == "app.bsky.feed.post")
            #expect(handleURI.recordKey == "abc123")

            let localURI = try ATProtocolURI(uriString: "at://laptop.local/app.bsky.feed.post/abc123")
            #expect(localURI.authority == "laptop.local")
            #expect(localURI.collection == "app.bsky.feed.post")
            #expect(localURI.recordKey == "abc123")

            let testURI = try ATProtocolURI(uriString: "at://john.test/app.bsky.feed.post/abc123")
            #expect(testURI.authority == "john.test")
            #expect(testURI.collection == "app.bsky.feed.post")
            #expect(testURI.recordKey == "abc123")
        }

        @Test("URI without rkey")
        func uRIWithoutRkey() throws {
            let uri = try ATProtocolURI(uriString: "at://did:plc:test12345/app.bsky.feed.post")
            #expect(uri.authority == "did:plc:test12345")
            #expect(uri.collection == "app.bsky.feed.post")
            #expect(uri.recordKey == nil)
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
            #expect(throws: (any Error).self) {
                try ATProtocolURI(uriString: "at://not_a_valid_authority/app.bsky.feed.post/abc123")
            }
            #expect(throws: (any Error).self) {
                try ATProtocolURI(uriString: "at://did:plc:test12345/invalidcollection/abc123")
            }
            #expect(throws: (any Error).self) {
                try ATProtocolURI(uriString: "at://did:plc:test12345/app.bsky.feed.post/.")
            }
            #expect(throws: (any Error).self) {
                try ATProtocolURI(uriString: "at://did:plc:test12345/app.bsky.feed.post/..")
            }
            #expect(throws: (any Error).self) {
                try ATProtocolURI(uriString: "at://did:plc:test12345/app.bsky.feed.post/abc/extra/segment")
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
        @Test("Valid handle creation and lowercasing")
        func validHandleCreation() throws {
            let handle1 = try Handle(handleString: "Alice.Bsky.Social")
            #expect(handle1.value == "alice.bsky.social")
            #expect(handle1.description == "alice.bsky.social")

            let handle2 = try Handle(handleString: "test.example-domain.com")
            #expect(handle2.value == "test.example-domain.com")
            #expect(handle2.description == "test.example-domain.com")

            // Handles with special/dev TLDs are syntactically valid per upstream @atproto/syntax
            let testHandles = [
                "john.test",
                "laptop.local",
                "service.arpa",
                "hidden.onion",
                "node.internal",
                "host.localhost",
                "sample.invalid",
                "demo.example",
                "peer.alt",
            ]
            for handleString in testHandles {
                let handle = try Handle(handleString: handleString)
                #expect(handle.value == handleString.lowercased())
            }
        }

        @Test("Invalid handle syntax creation")
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
            #expect(throws: (any Error).self) {
                try Handle(handleString: "john-.com")
            }
            #expect(throws: (any Error).self) {
                try Handle(handleString: "-john.com")
            }
            #expect(throws: (any Error).self) {
                try Handle(handleString: "john..com")
            }
            #expect(throws: (any Error).self) {
                try Handle(handleString: "john.0")
            }
            #expect(throws: (any Error).self) {
                try Handle(handleString: "127.0.0.1")
            }
        }

        @Test("Registration-time TLD policy checks")
        func registrationTimeTLDChecks() throws {
            // Disallowed TLD set must match upstream @atproto/syntax exactly (8 entries, .test excluded)
            let expectedDisallowed: Set<String> = [
                "alt", "arpa", "example", "internal", "invalid", "local", "localhost", "onion",
            ]
            #expect(Handle.disallowedTLDs == expectedDisallowed)
            #expect(!Handle.disallowedTLDs.contains("test"))

            // isValidTLD and isValidTld checks
            #expect(!Handle.isValidTLD("onion"))
            #expect(!Handle.isValidTLD(".onion"))
            #expect(!Handle.isValidTLD("local"))
            #expect(!Handle.isValidTLD(".local"))
            #expect(!Handle.isValidTld("arpa"))
            #expect(!Handle.isValidTld(".arpa"))
            #expect(Handle.isValidTLD("test"))
            #expect(Handle.isValidTLD(".test"))
            #expect(Handle.isValidTLD("com"))
            #expect(Handle.isValidTLD(".social"))
            #expect(Handle.isValidTld("app"))
            // isValidTLD and isValidTld with full handle string
            #expect(!Handle.isValidTld("alice.onion"))
            #expect(!Handle.isValidTLD("alice.onion"))
            #expect(!Handle.isValidTld("friend.expyuzz4wqqyqhjn.onion"))
            #expect(!Handle.isValidTld("laptop.local"))
            #expect(!Handle.isValidTld("SRI-NIC.ARPA"))
            #expect(Handle.isValidTld("alice.bsky.social"))
            #expect(Handle.isValidTld("john.test"))
            #expect(Handle.isValidTld("jan.test"))

            // Instance hasDisallowedTLD checks
            let onionHandle = try Handle(handleString: "hidden.onion")
            #expect(onionHandle.hasDisallowedTLD)
            #expect(onionHandle.hasDisallowedTld)

            let localHandle = try Handle(handleString: "laptop.local")
            #expect(localHandle.hasDisallowedTLD)

            let testHandle = try Handle(handleString: "john.test")
            #expect(!testHandle.hasDisallowedTLD)
            #expect(!testHandle.hasDisallowedTld)

            let normalHandle = try Handle(handleString: "alice.bsky.social")
            #expect(!normalHandle.hasDisallowedTLD)
            #expect(!normalHandle.hasDisallowedTld)
        }

        @Test("Handle length limits")
        func handleLengthLimits() {
            let longHandle = String(repeating: "a", count: 254) + ".com"
            #expect(throws: (any Error).self) {
                try Handle(handleString: longHandle)
            }

            // Individual DNS labels are limited to 63 characters; build a long-but-valid handle
            let validLengthHandle = (0 ..< 4).map { _ in String(repeating: "a", count: 60) }.joined(separator: ".") + ".com"
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

            // NSID segments are limited to 63 characters; build a long-but-valid NSID
            let validLengthNSID = "app.bsky." + String(repeating: "a", count: 63)
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
                try RecordKey(keyString: ".")
            }
            #expect(throws: (any Error).self) {
                try RecordKey(keyString: "..")
            }
            #expect(throws: Never.self) {
                try RecordKey(keyString: "...")
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
