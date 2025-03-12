import Foundation

// lexicon: 1, id: com.atproto.server.requestPasswordReset

public enum ComAtprotoServerRequestPasswordReset {
    public static let typeIdentifier = "com.atproto.server.requestPasswordReset"
    public struct Input: ATProtocolCodable {
        public let email: String

        // Standard public initializer
        public init(email: String) {
            self.email = email
        }
    }
}

public extension ATProtoClient.Com.Atproto.Server {
    /// Initiate a user account password reset via email.
    func requestPasswordReset(
        input: ComAtprotoServerRequestPasswordReset.Input

    ) async throws -> Int {
        let endpoint = "com.atproto.server.requestPasswordReset"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        let (_, response) = try await networkManager.performRequest(urlRequest)
        let responseCode = response.statusCode
        return responseCode
    }
}
