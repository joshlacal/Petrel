import Foundation

// lexicon: 1, id: com.atproto.admin.updateAccountSigningKey

public enum ComAtprotoAdminUpdateAccountSigningKey {
    public static let typeIdentifier = "com.atproto.admin.updateAccountSigningKey"
    public struct Input: ATProtocolCodable {
        public let did: DID
        public let signingKey: DID

        /// Standard public initializer
        public init(did: DID, signingKey: DID) {
            self.did = did
            self.signingKey = signingKey
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            did = try container.decode(DID.self, forKey: .did)

            signingKey = try container.decode(DID.self, forKey: .signingKey)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(did, forKey: .did)

            try container.encode(signingKey, forKey: .signingKey)
        }

        private enum CodingKeys: String, CodingKey {
            case did
            case signingKey
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)

            let signingKeyValue = try signingKey.toCBORValue()
            map = map.adding(key: "signingKey", value: signingKeyValue)

            return map
        }
    }
}

public extension ATProtoClient.Com.Atproto.Admin {
    // MARK: - updateAccountSigningKey

    /// Administrative action to update an account's signing key in their Did document.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: The HTTP response code
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func updateAccountSigningKey(
        input: ComAtprotoAdminUpdateAccountSigningKey.Input

    ) async throws -> Int {
        let endpoint = "com.atproto.admin.updateAccountSigningKey"

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
        let serviceDID = await networkService.getServiceDID(for: "com.atproto.admin.updateAccountSigningKey")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (_, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        return response.statusCode
    }
}
