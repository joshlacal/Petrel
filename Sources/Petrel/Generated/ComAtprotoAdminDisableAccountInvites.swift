import Foundation

// lexicon: 1, id: com.atproto.admin.disableAccountInvites

public enum ComAtprotoAdminDisableAccountInvites {
    public static let typeIdentifier = "com.atproto.admin.disableAccountInvites"
    public struct Input: ATProtocolCodable {
        public let account: DID
        public let note: String?

        // Standard public initializer
        public init(account: DID, note: String? = nil) {
            self.account = account
            self.note = note
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            account = try container.decode(DID.self, forKey: .account)

            note = try container.decodeIfPresent(String.self, forKey: .note)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(account, forKey: .account)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(note, forKey: .note)
        }

        private enum CodingKeys: String, CodingKey {
            case account
            case note
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let accountValue = try (account as? DAGCBOREncodable)?.toCBORValue() ?? account
            map = map.adding(key: "account", value: accountValue)

            if let value = note {
                // Encode optional property even if it's an empty array for CBOR

                let noteValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "note", value: noteValue)
            }

            return map
        }
    }
}

public extension ATProtoClient.Com.Atproto.Admin {
    /// Disable an account from receiving new invite codes, but does not invalidate existing codes.
    func disableAccountInvites(
        input: ComAtprotoAdminDisableAccountInvites.Input

    ) async throws -> Int {
        let endpoint = "com.atproto.admin.disableAccountInvites"

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
