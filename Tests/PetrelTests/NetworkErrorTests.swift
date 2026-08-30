import Foundation
import SwiftCBOR

private enum TestCBORWriter {
    static func header(major: UInt8, argument: UInt64) -> Data {
        let prefix = major << 5
        var result = Data()
        switch argument {
        case 0 ..< 24:
            result.append(prefix | UInt8(argument))
        case 24 ... UInt64(UInt8.max):
            result.append(prefix | 24)
            result.append(UInt8(argument))
        case (UInt64(UInt8.max) + 1) ... UInt64(UInt16.max):
            result.append(prefix | 25)
            var value = UInt16(argument).bigEndian
            result.append(Data(bytes: &value, count: MemoryLayout<UInt16>.size))
        case (UInt64(UInt16.max) + 1) ... UInt64(UInt32.max):
            result.append(prefix | 26)
            var value = UInt32(argument).bigEndian
            result.append(Data(bytes: &value, count: MemoryLayout<UInt32>.size))
        default:
            result.append(prefix | 27)
            var value = argument.bigEndian
            result.append(Data(bytes: &value, count: MemoryLayout<UInt64>.size))
        }
        return result
    }

    static func uint(_ value: UInt64) -> Data {
        header(major: 0, argument: value)
    }

    static func negative(_ value: Int64) -> Data {
        header(major: 1, argument: UInt64(-1 - value))
    }

    static func text(_ value: String) -> Data {
        let utf8 = Data(value.utf8)
        return header(major: 3, argument: UInt64(utf8.count)) + utf8
    }

    static func map(_ pairs: [(String, Data)]) -> Data {
        let sorted = pairs.sorted { a, b in
            let aBytes = a.0.utf8
            let bBytes = b.0.utf8
            if aBytes.count != bBytes.count {
                return aBytes.count < bBytes.count
            }
            return aBytes.lexicographicallyPrecedes(bBytes)
        }
        return sorted.reduce(header(major: 5, argument: UInt64(sorted.count))) { $0 + text($1.0) + $1.1 }
    }
}
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

        let invalidResponseError = NetworkError.invalidResponse(description: "unexpected payload")
        #expect(invalidResponseError.localizedDescription.contains("response"))

        let decodingError = NetworkError.decodingError
        #expect(decodingError.localizedDescription.contains("decode"))
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

    @Test("WebSocket frame integer boundaries: Int.max succeeds and UInt64 > Int.max throws typed error")
    func webSocketFrameIntegerBoundaries() throws {
        // Frame header: op = 1, t = "#message"
        let header = TestCBORWriter.map([
            ("op", TestCBORWriter.uint(1)),
            ("t", TestCBORWriter.text("#message")),
        ])

        // Payload with Int.max (within range)
        let payloadValid = TestCBORWriter.map([
            ("number", TestCBORWriter.uint(UInt64(Int.max))),
        ])
        let validFrame = header + payloadValid
        let decodedValid = try ATProtoWebSocketFrameDecoder.decodeFrame(validFrame)
        #expect(decodedValid.messageType == "#message")

        // Payload with UInt64.max (> Int.max)
        let payloadOverflow = TestCBORWriter.map([
            ("number", TestCBORWriter.uint(UInt64.max)),
        ])
        let overflowFrame = header + payloadOverflow
        #expect(throws: NetworkError.self) {
            _ = try ATProtoWebSocketFrameDecoder.decodeFrame(overflowFrame)
        }

        // Payload with Int64.min (representable negative integer boundary: -Int64.max - 1 = Int64.min)
        let payloadIntMin = TestCBORWriter.map([
            ("number", TestCBORWriter.negative(Int64.min)),
        ])
        let intMinFrame = header + payloadIntMin
        let decodedIntMin = try ATProtoWebSocketFrameDecoder.decodeFrame(intMinFrame)
        #expect(decodedIntMin.messageType == "#message")

        // Payload with negative integer underflowing Int64 boundary (arg = UInt64.max)
        let payloadUnderflow = TestCBORWriter.map([
            ("number", TestCBORWriter.header(major: 1, argument: UInt64.max)),
        ])
        let underflowFrame = header + payloadUnderflow
        #expect(throws: NetworkError.self) {
            _ = try ATProtoWebSocketFrameDecoder.decodeFrame(underflowFrame)
        }

        // Payload with negative integer underflowing Int64 boundary (arg = UInt64(Int64.max) + 1)
        let payloadUnderflowBoundary = TestCBORWriter.map([
            ("number", TestCBORWriter.header(major: 1, argument: UInt64(Int64.max) + 1)),
        ])
        let underflowBoundaryFrame = header + payloadUnderflowBoundary
        #expect(throws: NetworkError.self) {
            _ = try ATProtoWebSocketFrameDecoder.decodeFrame(underflowBoundaryFrame)
        }
    }
}

@Suite("Auth Error Tests")
struct AuthErrorTests {
    @Test("AuthError descriptions should be informative")
    func authErrorDescriptions() {
        let invalidCredentialsError = AuthError.invalidCredentials
        #expect(invalidCredentialsError.localizedDescription.contains("username or password"))

        let authFailedError = AuthError.authorizationFailed
        #expect(authFailedError.localizedDescription.contains("Authentication failed"))

        let invalidResponseError = AuthError.invalidResponse
        #expect(invalidResponseError.localizedDescription.contains("response"))

        let networkError = AuthError.networkError(NSError(domain: "Network", code: 123))
        #expect(networkError.localizedDescription.localizedCaseInsensitiveContains("network"))

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
        #expect(tidStruct.description.count == 13)
    }
}
