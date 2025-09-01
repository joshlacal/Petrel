import Foundation
@testable import Petrel
import Testing

@Suite("Basic Swift Testing Verification")
struct BasicSwiftTestingTests {
    
    @Test("Swift Testing framework works correctly")
    func testSwiftTestingFramework() {
        // Basic test to verify Swift Testing is working
        #expect(true == true, "Basic boolean test should pass")
        #expect(1 + 1 == 2, "Basic arithmetic should work")
        #expect("hello".uppercased() == "HELLO", "Basic string operations should work")
    }
    
    @Test("OAuthConfig can be created")
    func testOAuthConfigCreation() {
        let config = OAuthConfig(
            clientId: "test-client",
            redirectUri: "test://callback",
            scope: "atproto"
        )
        
        #expect(config.clientId == "test-client", "Should store client ID")
        #expect(config.redirectUri == "test://callback", "Should store redirect URI")
        #expect(config.scope == "atproto", "Should store scope")
    }
    
    @Test("CID parsing works for valid CIDs")
    func testValidCIDParsing() throws {
        let validCID = "bafyreigcxd76a5xqjzw2l6fq3u7d26hjtybdslqj2kxlzpvfyrvhycbr2a"
        let cid = try CID.parse(validCID)
        
        #expect(cid.description == validCID, "CID should parse and stringify correctly")
    }
    
    @Test("CID parsing rejects invalid CIDs")
    func testInvalidCIDParsing() {
        let invalidCID = "not-a-valid-cid"
        
        #expect(throws: (any Error).self) {
            try CID.parse(invalidCID)
        }
    }
    
    @Test("DID creation works for valid DIDs")
    func testValidDIDCreation() throws {
        let validDID = "did:plc:abcd1234"
        let did = try DID(didString: validDID)
        
        #expect(did.description == validDID, "DID should create and stringify correctly")
    }
    
    @Test("DID creation rejects invalid DIDs")
    func testInvalidDIDCreation() {
        let invalidDID = "not-a-valid-did"
        
        #expect(throws: (any Error).self) {
            try DID(didString: invalidDID)
        }
    }
    
    @Test("AppBskyFeedGetTimeline parameters work correctly")
    func testTimelineParameters() {
        let params = AppBskyFeedGetTimeline.Parameters(
            algorithm: "reverse-chronological",
            limit: 50,
            cursor: "test-cursor"
        )
        
        #expect(params.algorithm == "reverse-chronological")
        #expect(params.limit == 50)
        #expect(params.cursor == "test-cursor")
    }
    
    @Test("ATProtocolDate works with current date")
    func testATProtocolDate() {
        let now = Date()
        let atDate = ATProtocolDate(date: now)
        
        #expect(atDate.date.timeIntervalSince1970 == now.timeIntervalSince1970, accuracy: 1.0)
    }
    
    @Test("Basic async test functionality")
    func testAsyncFunctionality() async throws {
        // Test that async tests work
        try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        
        #expect(true, "Async test should complete successfully")
    }
    
    @Test("Error throwing test functionality")
    func testErrorThrowing() throws {
        // Test that throwing tests work
        struct TestError: Error {}
        
        func throwingFunction() throws -> Int {
            throw TestError()
        }
        
        #expect(throws: TestError.self) {
            try throwingFunction()
        }
    }
    
    @Test("Collections and data structures")
    func testCollections() {
        let array = [1, 2, 3, 4, 5]
        let filtered = array.filter { $0 > 3 }
        
        #expect(filtered.count == 2)
        #expect(filtered.contains(4))
        #expect(filtered.contains(5))
        #expect(!filtered.contains(1))
    }
}