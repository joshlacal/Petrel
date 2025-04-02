import Foundation

// lexicon: 1, id: com.atproto.admin.updateAccountPassword

public enum ComAtprotoAdminUpdateAccountPassword {
    public static let typeIdentifier = "com.atproto.admin.updateAccountPassword"
    public struct Input: ATProtocolCodable {
        public let did: DID
        public let password: String

        // Standard public initializer
        public init(did: DID, password: String) {
            self.did = did
            self.password = password
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            did = try container.decode(DID.self, forKey: .did)

            password = try container.decode(String.self, forKey: .password)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(did, forKey: .did)

            try container.encode(password, forKey: .password)
        }

        private enum CodingKeys: String, CodingKey {
            case did
            case password
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let didValue = try (did as? DAGCBOREncodable)?.toCBORValue() ?? did
            map = map.adding(key: "did", value: didValue)

            let passwordValue = try (password as? DAGCBOREncodable)?.toCBORValue() ?? password
            map = map.adding(key: "password", value: passwordValue)

            return map
        }
    }
}

public extension ATProtoClient.Com.Atproto.Admin {
    /// Update the password for a user account as an administrator.
    func updateAccountPassword(
        input: ComAtprotoAdminUpdateAccountPassword.Input

    ) async throws -> Int {
        let endpoint = "com.atproto.admin.updateAccountPassword"

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
