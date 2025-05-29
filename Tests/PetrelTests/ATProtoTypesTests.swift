@testable import Petrel
import Testing
import Foundation

@Suite("ATProto Types Tests")
struct ATProtoTypesTests {
    
    @Suite("DID Tests")
    struct DIDTests {
        
        @Test("Valid DID creation")
        func testValidDIDCreation() {
            #expect(DID("did:plc:abcd1234")?.description == "did:plc:abcd1234")
            #expect(DID("did:web:example.com")?.description == "did:web:example.com")
            #expect(DID("did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK")?.description != nil)
        }
        
        @Test("Invalid DID creation")
        func testInvalidDIDCreation() {
            #expect(DID("") == nil)
            #expect(DID("invalid") == nil)
            #expect(DID("did:") == nil)
            #expect(DID("di:plc:test") == nil)
            #expect(DID("did::test") == nil)
        }
        
        @Test("DID bounds checking")
        func testDIDBoundsChecking() {
            #expect(DID("did") == nil) // Too short for dropFirst(4)
            #expect(DID("di") == nil)
            #expect(DID("d") == nil)
        }
    }
    
    @Suite("ATProtocolURI Tests")
    struct ATProtocolURITests {
        
        @Test("Valid URI creation")
        func testValidURICreation() throws {
            let uri = try ATProtocolURI("at://did:plc:test/app.bsky.feed.post/abc123")
            #expect(uri.repo == "did:plc:test")
            #expect(uri.collection == "app.bsky.feed.post")
            #expect(uri.rkey == "abc123")
        }
        
        @Test("URI without rkey")
        func testURIWithoutRkey() throws {
            let uri = try ATProtocolURI("at://did:plc:test/app.bsky.feed.post")
            #expect(uri.repo == "did:plc:test")
            #expect(uri.collection == "app.bsky.feed.post")
            #expect(uri.rkey == nil)
        }
        
        @Test("Invalid URI creation")
        func testInvalidURICreation() {
            #expect(throws: ATProtocolURIError.invalidFormat) {
                try ATProtocolURI("")
            }
            #expect(throws: ATProtocolURIError.invalidFormat) {
                try ATProtocolURI("invalid")
            }
            #expect(throws: ATProtocolURIError.invalidFormat) {
                try ATProtocolURI("at://") // Too short
            }
        }
        
        @Test("URI bounds checking") 
        func testURIBoundsChecking() {
            #expect(throws: ATProtocolURIError.invalidFormat) {
                try ATProtocolURI("at://") // Too short for dropFirst(5)
            }
            #expect(throws: ATProtocolURIError.invalidFormat) {
                try ATProtocolURI("at:/") // Too short
            }
        }
    }
    
    @Suite("Handle Tests")
    struct HandleTests {
        
        @Test("Valid handle creation")
        func testValidHandleCreation() {
            #expect(Handle("alice.bsky.social")?.description == "alice.bsky.social")
            #expect(Handle("test.example.com")?.description == "test.example.com")
            #expect(Handle("user.localhost")?.description == "user.localhost")
        }
        
        @Test("Invalid handle creation")
        func testInvalidHandleCreation() {
            #expect(Handle("") == nil)
            #expect(Handle(".invalid") == nil)
            #expect(Handle("invalid.") == nil)
            #expect(Handle("no-dots") == nil)
            #expect(Handle("has spaces.com") == nil)
        }
        
        @Test("Handle length limits")
        func testHandleLengthLimits() {
            let longHandle = String(repeating: "a", count: 254) + ".com"
            #expect(Handle(longHandle) == nil)
            
            let validLengthHandle = String(repeating: "a", count: 240) + ".com"
            #expect(Handle(validLengthHandle) != nil)
        }
    }
    
    @Suite("NSID Tests")
    struct NSIDTests {
        
        @Test("Valid NSID creation")
        func testValidNSIDCreation() {
            #expect(NSID("app.bsky.feed.post")?.description == "app.bsky.feed.post")
            #expect(NSID("com.example.test")?.description == "com.example.test")
        }
        
        @Test("Invalid NSID creation")
        func testInvalidNSIDCreation() {
            #expect(NSID("") == nil)
            #expect(NSID("invalid") == nil)
            #expect(NSID("app.bsky.") == nil)
            #expect(NSID(".invalid") == nil)
        }
        
        @Test("NSID length limits")
        func testNSIDLengthLimits() {
            let longNSID = String(repeating: "a", count: 585)
            #expect(NSID(longNSID) == nil)
            
            let validLengthNSID = "app.bsky." + String(repeating: "a", count: 500)
            #expect(NSID(validLengthNSID) != nil)
        }
    }
    
    @Suite("RecordKey Tests")
    struct RecordKeyTests {
        
        @Test("Valid RecordKey creation")
        func testValidRecordKeyCreation() {
            #expect(RecordKey("abc123")?.description == "abc123")
            #expect(RecordKey("test-key_123")?.description == "test-key_123")
            #expect(RecordKey("2024-01-01")?.description == "2024-01-01")
        }
        
        @Test("Invalid RecordKey creation")
        func testInvalidRecordKeyCreation() {
            #expect(RecordKey("") == nil)
            #expect(RecordKey("has spaces") == nil)
            #expect(RecordKey("has/slash") == nil)
        }
        
        @Test("RecordKey length limits")
        func testRecordKeyLengthLimits() {
            let longKey = String(repeating: "a", count: 513)
            #expect(RecordKey(longKey) == nil)
            
            let validLengthKey = String(repeating: "a", count: 512)
            #expect(RecordKey(validLengthKey) != nil)
        }
        
        @Test("RecordKey fallback validation")
        func testRecordKeyFallbackValidation() {
            // Test that the fallback validation works when regex fails
            #expect(RecordKey("valid123") != nil)
            #expect(RecordKey("test_key") != nil)
            #expect(RecordKey("2024-01-01") != nil)
        }
    }
}