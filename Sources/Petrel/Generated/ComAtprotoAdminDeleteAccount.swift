import Foundation

// lexicon: 1, id: com.atproto.admin.deleteAccount

public enum ComAtprotoAdminDeleteAccount {
    public static let typeIdentifier = "com.atproto.admin.deleteAccount"
    public struct Input: ATProtocolCodable {
        public let did: DID

        // Standard public initializer
        public init(did: DID) {
            self.did = did
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            did = try container.decode(DID.self, forKey: .did)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(did, forKey: .did)
        }

        private enum CodingKeys: String, CodingKey {
            case did
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let didValue = try (did as? DAGCBOREncodable)?.toCBORValue() ?? did
            map = map.adding(key: "did", value: didValue)

            return map
        }
    }
}

public extension ATProtoClient.Com.Atproto.Admin {
    /// Delete a user account as an administrator.
    func deleteAccount(
        input: ComAtprotoAdminDeleteAccount.Input

    ) async throws -> Int {
        let endpoint = "com.atproto.admin.deleteAccount"

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
