import Foundation

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

            if let value = emailAuthFactor {
                try container.encode(value, forKey: .emailAuthFactor)
            }

            if let value = token {
                try container.encode(value, forKey: .token)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case email
            case emailAuthFactor
            case token
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
    /// Update an account's email.
    func updateEmail(
        input: ComAtprotoServerUpdateEmail.Input

    ) async throws -> Int {
        let endpoint = "com.atproto.server.updateEmail"

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
