import Foundation

// lexicon: 1, id: com.atproto.server.resetPassword

public enum ComAtprotoServerResetPassword {
    public static let typeIdentifier = "com.atproto.server.resetPassword"
    public struct Input: ATProtocolCodable {
        public let token: String
        public let password: String

        // Standard public initializer
        public init(token: String, password: String) {
            self.token = token
            self.password = password
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            token = try container.decode(String.self, forKey: .token)

            password = try container.decode(String.self, forKey: .password)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(token, forKey: .token)

            try container.encode(password, forKey: .password)
        }

        private enum CodingKeys: String, CodingKey {
            case token
            case password
        }
    }

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case expiredToken = "ExpiredToken."
        case invalidToken = "InvalidToken."
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.Com.Atproto.Server {
    /// Reset a user account password using a token.
    func resetPassword(
        input: ComAtprotoServerResetPassword.Input

    ) async throws -> Int {
        let endpoint = "com.atproto.server.resetPassword"

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
