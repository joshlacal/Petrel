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
    // MARK: - disableAccountInvites

    /// Disable an account from receiving new invite codes, but does not invalidate existing codes.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: The HTTP response code
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func disableAccountInvites(
        input: ComAtprotoAdminDisableAccountInvites.Input

    ) async throws -> Int {
        let endpoint = "com.atproto.admin.disableAccountInvites"

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
        let serviceDID = await networkService.getServiceDID(for: "com.atproto.admin.disableAccountInvites")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (_, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        return responseCode
    }
}
