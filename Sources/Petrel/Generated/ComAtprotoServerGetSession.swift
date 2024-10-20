import Foundation
import ZippyJSON

// lexicon: 1, id: com.atproto.server.getSession

public enum ComAtprotoServerGetSession {
    public static let typeIdentifier = "com.atproto.server.getSession"

    public struct Output: ATProtocolCodable {
        public let handle: String

        public let did: String

        public let email: String?

        public let emailConfirmed: Bool?

        public let emailAuthFactor: Bool?

        public let didDoc: DIDDocument?

        public let active: Bool?

        public let status: String?

        // Standard public initializer
        public init(
            handle: String,

            did: String,

            email: String? = nil,

            emailConfirmed: Bool? = nil,

            emailAuthFactor: Bool? = nil,

            didDoc: DIDDocument? = nil,

            active: Bool? = nil,

            status: String? = nil

        ) {
            self.handle = handle

            self.did = did

            self.email = email

            self.emailConfirmed = emailConfirmed

            self.emailAuthFactor = emailAuthFactor

            self.didDoc = didDoc

            self.active = active

            self.status = status
        }
    }
}

public extension ATProtoClient.Com.Atproto.Server {
    /// Get information about the current auth session. Requires auth.
    func getSession() async throws -> (responseCode: Int, data: ComAtprotoServerGetSession.Output?) {
        let endpoint = "com.atproto.server.getSession"

        let queryItems: [URLQueryItem]? = nil

        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest)
        let responseCode = response.statusCode

        // Content-Type validation
        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        // Data decoding and validation

        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(ComAtprotoServerGetSession.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
