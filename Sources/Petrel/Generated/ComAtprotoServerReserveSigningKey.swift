import Foundation

// lexicon: 1, id: com.atproto.server.reserveSigningKey

public enum ComAtprotoServerReserveSigningKey {
    public static let typeIdentifier = "com.atproto.server.reserveSigningKey"
    public struct Input: ATProtocolCodable {
        public let did: DID?

        // Standard public initializer
        public init(did: DID? = nil) {
            self.did = did
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            did = try container.decodeIfPresent(DID.self, forKey: .did)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(did, forKey: .did)
        }

        private enum CodingKeys: String, CodingKey {
            case did
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            if let value = did {
                // Encode optional property even if it's an empty array for CBOR
                let didValue = try value.toCBORValue()
                map = map.adding(key: "did", value: didValue)
            }

            return map
        }
    }

    public struct Output: ATProtocolCodable {
        public let signingKey: String

        // Standard public initializer
        public init(
            signingKey: String

        ) {
            self.signingKey = signingKey
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            signingKey = try container.decode(String.self, forKey: .signingKey)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(signingKey, forKey: .signingKey)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let signingKeyValue = try signingKey.toCBORValue()
            map = map.adding(key: "signingKey", value: signingKeyValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case signingKey
        }
    }
}

public extension ATProtoClient.Com.Atproto.Server {
    // MARK: - reserveSigningKey

    /// Reserve a repo signing key, for use with account creation. Necessary so that a DID PLC update operation can be constructed during an account migraiton. Public and does not require auth; implemented by PDS. NOTE: this endpoint may change when full account migration is implemented.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func reserveSigningKey(
        input: ComAtprotoServerReserveSigningKey.Input

    ) async throws -> (responseCode: Int, data: ComAtprotoServerReserveSigningKey.Output?) {
        let endpoint = "com.atproto.server.reserveSigningKey"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        headers["Accept"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        let (responseData, response) = try await networkService.performRequest(urlRequest)

        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(ComAtprotoServerReserveSigningKey.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
