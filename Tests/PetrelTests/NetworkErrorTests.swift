import Foundation
@testable import Petrel
import Testing

@Suite("Network Error Tests")
struct NetworkErrorTests {
    @Test("NetworkError descriptions should be informative")
    func networkErrorDescriptions() {
        let invalidURLError = NetworkError.invalidURL
        #expect(invalidURLError.localizedDescription.contains("URL"))

        let requestFailedError = NetworkError.requestFailed
        #expect(requestFailedError.localizedDescription.contains("request"))

        let invalidResponseError = NetworkError.invalidResponse
        #expect(invalidResponseError.localizedDescription.contains("response"))

        let decodingError = NetworkError.decodingError
        #expect(decodingError.localizedDescription.contains("decoding"))
    }

    @Test("NetworkError should handle various HTTP status codes")
    func hTTPStatusCodeErrors() {
        let error401 = NetworkError.responseError(statusCode: 401)
        #expect(error401.localizedDescription.contains("401"))

        let error404 = NetworkError.responseError(statusCode: 404)
        #expect(error404.localizedDescription.contains("404"))

        let error500 = NetworkError.responseError(statusCode: 500)
        #expect(error500.localizedDescription.contains("500"))
    }

    @Test("NetworkError should handle bad request descriptions")
    func testBadRequestError() {
        let badRequestError = NetworkError.badRequest(description: "Invalid parameter")
        #expect(badRequestError.localizedDescription.contains("Invalid parameter"))
    }

    @Test("NetworkError should handle content type errors")
    func testContentTypeError() {
        let contentTypeError = NetworkError.invalidContentType(expected: "application/json", actual: "text/html")
        #expect(contentTypeError.localizedDescription.contains("application/json"))
        #expect(contentTypeError.localizedDescription.contains("text/html"))
    }
}

@Suite("Auth Error Tests")
struct AuthErrorTests {
    @Test("AuthError descriptions should be informative")
    func authErrorDescriptions() {
        let invalidCredentialsError = AuthError.invalidCredentials
        #expect(invalidCredentialsError.localizedDescription.contains("credentials"))

        let authFailedError = AuthError.authorizationFailed
        #expect(authFailedError.localizedDescription.contains("authorization"))

        let invalidResponseError = AuthError.invalidResponse
        #expect(invalidResponseError.localizedDescription.contains("response"))

        let networkError = AuthError.networkError(NSError(domain: "Network", code: 123))
        #expect(networkError.localizedDescription.contains("network"))

        let invalidConfigError = AuthError.invalidOAuthConfiguration
        #expect(invalidConfigError.localizedDescription.contains("OAuth") || invalidConfigError.localizedDescription.contains("configuration"))
    }

    @Test("AuthError equality should work")
    func authErrorEquality() {
        #expect(AuthError.invalidCredentials == AuthError.invalidCredentials)
        #expect(AuthError.authorizationFailed == AuthError.authorizationFailed)
        #expect(AuthError.invalidResponse == AuthError.invalidResponse)
        #expect(AuthError.invalidOAuthConfiguration == AuthError.invalidOAuthConfiguration)

        #expect(AuthError.invalidCredentials != AuthError.authorizationFailed)
    }
}

@Suite("TID Generator Tests")
struct TIDGeneratorTests {
    @Test("TID should generate valid timestamps")
    func tIDGeneration() async {
        let tid = await TIDGenerator.next()
        #expect(tid.count > 0)

        // TID should be a valid timestamp-based identifier
        // Basic format check - should contain only valid characters
        let validCharacters = CharacterSet(charactersIn: "234567abcdefghijklmnopqrstuvwxyz")
        let tidCharacterSet = CharacterSet(charactersIn: tid)
        #expect(validCharacters.isSuperset(of: tidCharacterSet))
    }

    @Test("TID should generate unique values")
    func tIDUniqueness() async {
        let tid1 = await TIDGenerator.next()
        let tid2 = await TIDGenerator.next()

        // TIDs generated at different times should be different
        #expect(tid1 != tid2)
    }

    @Test("TID should be consistent length")
    func tIDLength() async {
        let tid1 = await TIDGenerator.next()
        let tid2 = await TIDGenerator.next()
        let tid3 = await TIDGenerator.next()

        // All TIDs should have the same length (13 characters)
        #expect(tid1.count == 13)
        #expect(tid2.count == 13)
        #expect(tid3.count == 13)
    }

    @Test("TID struct generation")
    func tIDStructGeneration() async {
        let tidStruct = await TIDGenerator.nextTID()
        #expect(tidStruct.tidString.count == 13)
    }
}
