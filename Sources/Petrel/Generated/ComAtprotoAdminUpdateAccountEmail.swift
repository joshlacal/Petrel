import Foundation

// lexicon: 1, id: com.atproto.admin.updateAccountEmail

public enum ComAtprotoAdminUpdateAccountEmail {
    public static let typeIdentifier = "com.atproto.admin.updateAccountEmail"
    public struct Input: ATProtocolCodable {
        public let account: ATIdentifier
        public let email: String

        // Standard public initializer
        public init(account: ATIdentifier, email: String) {
            self.account = account
            self.email = email
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            account = try container.decode(ATIdentifier.self, forKey: .account)

            email = try container.decode(String.self, forKey: .email)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(account, forKey: .account)

            try container.encode(email, forKey: .email)
        }

        private enum CodingKeys: String, CodingKey {
            case account
            case email
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Add fields in lexicon-defined order

            let accountValue = try (account as? DAGCBOREncodable)?.toCBORValue() ?? account
            map = map.adding(key: "account", value: accountValue)

            let emailValue = try (email as? DAGCBOREncodable)?.toCBORValue() ?? email
            map = map.adding(key: "email", value: emailValue)

            return map
        }
    }
}

public extension ATProtoClient.Com.Atproto.Admin {
    /// Administrative action to update an account's email.
    func updateAccountEmail(
        input: ComAtprotoAdminUpdateAccountEmail.Input

    ) async throws -> Int {
        let endpoint = "com.atproto.admin.updateAccountEmail"

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
