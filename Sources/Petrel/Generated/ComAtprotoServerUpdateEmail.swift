import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// lexicon: 1, id: com.atproto.server.updateEmail

public enum ComAtprotoServerUpdateEmail {
    public static let typeIdentifier = "com.atproto.server.updateEmail"
    public struct Input: ATProtocolCodable {
        public let email: String
        public let emailAuthFactor: Bool?
        public let token: String?

        // Standard public initializer
        public init(email: String, emailAuthFactor: Bool? = nil, token: String? = nil) {
            self.email = email
            self.emailAuthFactor = emailAuthFactor
            self.token = token
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            email = try container.decode(String.self, forKey: .email)

            emailAuthFactor = try container.decodeIfPresent(Bool.self, forKey: .emailAuthFactor)

            token = try container.decodeIfPresent(String.self, forKey: .token)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(email, forKey: .email)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(emailAuthFactor, forKey: .emailAuthFactor)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(token, forKey: .token)
        }

        private enum CodingKeys: String, CodingKey {
            case email
            case emailAuthFactor
            case token
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let emailValue = try email.toCBORValue()
            map = map.adding(key: "email", value: emailValue)

            if let value = emailAuthFactor {
                // Encode optional property even if it's an empty array for CBOR
                let emailAuthFactorValue = try value.toCBORValue()
                map = map.adding(key: "emailAuthFactor", value: emailAuthFactorValue)
            }

            if let value = token {
                // Encode optional property even if it's an empty array for CBOR
                let tokenValue = try value.toCBORValue()
                map = map.adding(key: "token", value: tokenValue)
            }

            return map
        }
    }

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case expiredToken = "ExpiredToken."
        case invalidToken = "InvalidToken."
        case tokenRequired = "TokenRequired."
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.Com.Atproto.Server {
    // MARK: - updateEmail

    /// Update an account's email.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: The HTTP response code
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func updateEmail(
        input: ComAtprotoServerUpdateEmail.Input

    ) async throws -> Int {
        let endpoint = "com.atproto.server.updateEmail"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "com.atproto.server.updateEmail")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (_, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        return responseCode
    }
}
