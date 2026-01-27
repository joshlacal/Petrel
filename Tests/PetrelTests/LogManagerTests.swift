import Foundation
@testable import Petrel
import Testing

@Suite("LogManager Tests")
struct LogManagerTests {
    @Test("LogManager should not crash on nil values")
    func logManagerNilSafety() {
        // These should not crash
        LogManager.logSensitiveValue(nil, label: "test")
        LogManager.logDID(nil, label: "testDID")
        LogManager.logSensitiveValue("", label: "empty")
        LogManager.logDID("", label: "emptyDID")
    }

    @Test("LogManager categories should work")
    func logManagerCategories() {
        // These should not crash and should use different loggers
        LogManager.logInfo("Test message", category: .general)
        LogManager.logInfo("Network message", category: .network)
        LogManager.logInfo("Auth message", category: .authentication)

        LogManager.logError("Test error", category: .general)
        LogManager.logError("Network error", category: .network)
        LogManager.logError("Auth error", category: .authentication)
    }

    @Test("LogManager should handle sensitive request logging")
    func sensitiveRequestLogging() throws {
        let url = try #require(URL(string: "https://example.com/oauth/token"))
        var request = URLRequest(url: url)
        request.addValue("Bearer secret-token", forHTTPHeaderField: "Authorization")
        request.addValue("sensitive-dpop-proof", forHTTPHeaderField: "X-DPoP")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // This should not crash and should filter sensitive headers
        LogManager.logRequest(request)
    }

    @Test("LogManager should handle sensitive response logging")
    func sensitiveResponseLogging() throws {
        let url = try #require(URL(string: "https://example.com/oauth/token"))
        let response = try #require(HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "1.1",
            headerFields: [
                "Content-Type": "application/json",
                "Set-Cookie": "sensitive-session-id=123456",
                "X-Auth-Token": "secret-token",
            ]
        ))

        let responseData = """
        {
            "access_token": "secret-access-token",
            "refresh_token": "secret-refresh-token"
        }
        """.data(using: .utf8)!

        // This should not crash and should filter sensitive data
        LogManager.logResponse(response, data: responseData)
    }

    @Test("LogManager should handle non-token endpoint responses")
    func nonTokenEndpointLogging() throws {
        let url = try #require(URL(string: "https://example.com/api/posts"))
        let response = try #require(HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "1.1",
            headerFields: ["Content-Type": "application/json"]
        ))

        let responseData = """
        {
            "posts": [{"id": "123", "text": "Hello world"}]
        }
        """.data(using: .utf8)!

        // This should log the response body since it's not a token endpoint
        LogManager.logResponse(response, data: responseData)
    }

    @Test("LogManager should handle large responses")
    func largeResponseLogging() throws {
        let url = try #require(URL(string: "https://example.com/api/data"))
        let response = try #require(HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "1.1",
            headerFields: ["Content-Type": "application/json"]
        ))

        // Create a large response (over 1000 characters)
        let largeData = try #require(String(repeating: "x", count: 2000).data(using: .utf8))

        // This should truncate the response
        LogManager.logResponse(response, data: largeData)
    }

    @Test("LogManager should handle request with sensitive body")
    func sensitiveRequestBody() throws {
        let url = try #require(URL(string: "https://example.com/api/test"))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let sensitiveBody = """
        {
            "password": "secret123",
            "client_secret": "very-secret",
            "code": "auth-code-123"
        }
        """.data(using: .utf8)

        request.httpBody = sensitiveBody

        // This should detect sensitive data and not log the body
        LogManager.logRequest(request)
    }

    @Test("LogManager should handle safe request body")
    func safeRequestBody() throws {
        let url = try #require(URL(string: "https://example.com/api/posts"))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let safeBody = """
        {
            "title": "My Post",
            "content": "Hello world!"
        }
        """.data(using: .utf8)

        request.httpBody = safeBody

        // This should log the body since it doesn't contain sensitive data
        LogManager.logRequest(request)
    }
}
