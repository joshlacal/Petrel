import Foundation

// lexicon: 1, id: com.atproto.admin.enableAccountInvites

public enum ComAtprotoAdminEnableAccountInvites {
    public static let typeIdentifier = "com.atproto.admin.enableAccountInvites"
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

            let accountValue = try account.toCBORValue()
            map = map.adding(key: "account", value: accountValue)

            if let value = note {
                // Encode optional property even if it's an empty array for CBOR
                let noteValue = try value.toCBORValue()
                map = map.adding(key: "note", value: noteValue)
            }

            return map
        }
    }
}

public extension ATProtoClient.Com.Atproto.Admin {
    // MARK: - enableAccountInvites

    /// Re-enable an account's ability to receive invite codes.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: The HTTP response code
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func enableAccountInvites(
        input: ComAtprotoAdminEnableAccountInvites.Input

    ) async throws -> Int {
        let endpoint = "com.atproto.admin.enableAccountInvites"

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

        let (_, response) = try await networkService.performRequest(urlRequest)
        let responseCode = response.statusCode
        return responseCode
    }
}
