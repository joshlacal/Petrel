import Foundation
@testable import Petrel
import XCTest

final class ATProtoErrorTests: XCTestCase {
    private enum EndpointError: String, ATProtoErrorType {
        case destinationExists = "DestinationExists"

        // This wire value is deliberately invalid. Its presence makes the test
        // fail if the parser performs the legacy synthetic dotted lookup first.
        case syntheticDottedDestinationExists = "DestinationExists."
    }

    func testExactDeclaredErrorNameReturnsTypedErrorAndStatus() throws {
        let data = Data(
            #"{"error":"DestinationExists","message":"already saved"}"#.utf8
        )

        let parsed = try XCTUnwrap(
            ATProtoErrorParser.parse(
                data: data,
                statusCode: 409,
                errorType: EndpointError.self
            )
        )

        XCTAssertEqual(parsed.error, .destinationExists)
        XCTAssertEqual(parsed.message, "already saved")
        XCTAssertEqual(parsed.statusCode, 409)
    }

    func testUnknownErrorNameReturnsNil() {
        let data = Data(
            #"{"error":"UnknownError","message":"not declared"}"#.utf8
        )

        let parsed = ATProtoErrorParser.parse(
            data: data,
            statusCode: 400,
            errorType: EndpointError.self
        )

        XCTAssertNil(parsed)
    }

    func testMalformedJSONReturnsNil() {
        let data = Data(#"{"error":"DestinationExists""#.utf8)

        let parsed = ATProtoErrorParser.parse(
            data: data,
            statusCode: 500,
            errorType: EndpointError.self
        )

        XCTAssertNil(parsed)
    }

    func testParseGenericReturnsXRPCErrorWithCodeAndMessage() throws {
        let data = Data(
            #"{"error":"InvalidToken","message":"Token has expired"}"#.utf8
        )

        let parsed = try XCTUnwrap(
            ATProtoErrorParser.parseGeneric(
                data: data,
                statusCode: 400
            )
        )

        XCTAssertEqual(parsed.error, "InvalidToken")
        XCTAssertEqual(parsed.message, "Token has expired")
        XCTAssertEqual(parsed.statusCode, 400)
        XCTAssertEqual(parsed.errorDescription, "InvalidToken: Token has expired")
    }

    func testParseGenericReturnsXRPCErrorWithoutMessage() throws {
        let data = Data(
            #"{"error":"RateLimitExceeded"}"#.utf8
        )

        let parsed = try XCTUnwrap(
            ATProtoErrorParser.parseGeneric(
                data: data,
                statusCode: 429
            )
        )

        XCTAssertEqual(parsed.error, "RateLimitExceeded")
        XCTAssertNil(parsed.message)
        XCTAssertEqual(parsed.statusCode, 429)
        XCTAssertEqual(parsed.errorDescription, "RateLimitExceeded")
    }

    func testParseGenericFallbackToPlainText() throws {
        let data = Data("Internal Server Error".utf8)

        let parsed = try XCTUnwrap(
            ATProtoErrorParser.parseGeneric(
                data: data,
                statusCode: 500
            )
        )

        XCTAssertEqual(parsed.error, "HTTP 500")
        XCTAssertEqual(parsed.message, "Internal Server Error")
        XCTAssertEqual(parsed.statusCode, 500)
        XCTAssertEqual(parsed.errorDescription, "HTTP 500: Internal Server Error")
    }

    func testParseGenericEmptyDataReturnsNil() {
        let parsed = ATProtoErrorParser.parseGeneric(
            data: Data(),
            statusCode: 502
        )

        XCTAssertNil(parsed)
    }
}
