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
}
