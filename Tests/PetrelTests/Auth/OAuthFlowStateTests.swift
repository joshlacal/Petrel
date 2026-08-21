//
//  OAuthFlowStateTests.swift
//  PetrelTests
//

import Foundation
@testable import Petrel
import Testing

@Suite("OAuth Flow State and Error Tests")
struct OAuthFlowStateTests {
    @Test("AuthError invalidClientMetadata equality and description")
    func testInvalidClientMetadataError() {
        let err1 = AuthError.invalidClientMetadata("Native clients must authenticate using none method")
        let err2 = AuthError.invalidClientMetadata("Native clients must authenticate using none method")
        let err3 = AuthError.invalidClientMetadata("Different reason")

        #expect(err1 == err2)
        #expect(err1 != err3)
        #expect(err1.errorDescription?.contains("Native clients must authenticate using none method") == true)
    }

    @Test("Unauthenticated client startOAuthFlowWithState throws unauthenticatedClient")
    func testStartOAuthFlowWithStateUnauthenticated() async {
        let client = await ATProtoClient(baseURL: URL(string: "https://bsky.social")!)
        await #expect(throws: APIError.self) {
            try await client.startOAuthFlowWithState(identifier: "test.bsky.social")
        }
    }
}
