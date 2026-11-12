import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
@testable import Petrel
import Testing

/// HTTP header names are case-insensitive, and Foundation hands them back differently
/// on Darwin and on Linux. These build `HTTPURLResponse` values directly, so they run
/// without a transport on every platform.
@Suite("XRPC response headers are read case-insensitively")
struct XRPCResponseHeaderCasingTests {
    private static func response(status: Int, headers: [String: String]) throws -> HTTPURLResponse {
        let url = try #require(URL(string: "https://pds.example.com/xrpc/com.example.call"))
        return try #require(HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers))
    }

    @Test("Header names are lowercased whatever casing the server used", arguments: [
        ["RateLimit-Limit": "3000", "RateLimit-Remaining": "7", "RateLimit-Reset": "1767225600", "RateLimit-Policy": "3000;w=300", "Retry-After": "42"],
        ["ratelimit-limit": "3000", "ratelimit-remaining": "7", "ratelimit-reset": "1767225600", "ratelimit-policy": "3000;w=300", "retry-after": "42"],
        ["RATELIMIT-LIMIT": "3000", "RATELIMIT-REMAINING": "7", "RATELIMIT-RESET": "1767225600", "RATELIMIT-POLICY": "3000;w=300", "RETRY-AFTER": "42"],
        ["Ratelimit-Limit": "3000", "rateLimit-remaining": "7", "RateLimit-reset": "1767225600", "ratelimit-Policy": "3000;w=300", "retry-After": "42"],
    ])
    func errorCarriesRateLimitAndRetryAfter(headers: [String: String]) throws {
        let response = try Self.response(status: 429, headers: headers)
        let body = Data(#"{"error":"RateLimitExceeded","message":"Rate Limit Exceeded"}"#.utf8)

        let error = ATProtoErrorParser.xrpcError(data: body, response: response)

        #expect(error.error == "RateLimitExceeded")
        #expect(error.statusCode == 429)
        #expect(error.retryAfter == 42)
        let rateLimit = try #require(error.rateLimit)
        #expect(rateLimit.limit == 3000)
        #expect(rateLimit.remaining == 7)
        #expect(rateLimit.reset == Date(timeIntervalSince1970: 1_767_225_600))
        #expect(rateLimit.policy == "3000;w=300")
        #expect(Set(error.headers.keys) == ["ratelimit-limit", "ratelimit-remaining", "ratelimit-reset", "ratelimit-policy", "retry-after"])
    }

    @Test("Response metadata reads labelers and repo rev whatever the header casing", arguments: [
        ["Atproto-Content-Labelers": "did:plc:ar7c4by46qjdydhdevvrndac;redact, did:plc:abcdefghijklmnopqrstuvwx", "Atproto-Repo-Rev": "3lnz2hvdumk2a"],
        ["atproto-content-labelers": "did:plc:ar7c4by46qjdydhdevvrndac;redact, did:plc:abcdefghijklmnopqrstuvwx", "atproto-repo-rev": "3lnz2hvdumk2a"],
        ["ATPROTO-CONTENT-LABELERS": "did:plc:ar7c4by46qjdydhdevvrndac;redact, did:plc:abcdefghijklmnopqrstuvwx", "ATPROTO-REPO-REV": "3lnz2hvdumk2a"],
    ])
    func metadataReadsServiceHeaders(headers: [String: String]) throws {
        let response = try Self.response(status: 200, headers: headers)

        let metadata = XRPCResponseMetadata(
            statusCode: response.statusCode,
            headers: ATProtoErrorParser.headerFields(of: response)
        )

        #expect(metadata.repoRev == "3lnz2hvdumk2a")
        #expect(metadata.contentLabelers.map(\.did) == ["did:plc:ar7c4by46qjdydhdevvrndac", "did:plc:abcdefghijklmnopqrstuvwx"])
        #expect(metadata.contentLabelers.map(\.redact) == [true, false])
        #expect(metadata.rateLimit == nil)
    }
}
