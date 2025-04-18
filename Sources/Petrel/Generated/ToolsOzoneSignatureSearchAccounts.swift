import Foundation

// lexicon: 1, id: tools.ozone.signature.searchAccounts

public enum ToolsOzoneSignatureSearchAccounts {
    public static let typeIdentifier = "tools.ozone.signature.searchAccounts"
    public struct Parameters: Parametrizable {
        public let values: [String]
        public let cursor: String?
        public let limit: Int?

        public init(
            values: [String],
            cursor: String? = nil,
            limit: Int? = nil
        ) {
            self.values = values
            self.cursor = cursor
            self.limit = limit
        }
    }

    public struct Output: ATProtocolCodable {
        public let cursor: String?

        public let accounts: [ComAtprotoAdminDefs.AccountView]

        // Standard public initializer
        public init(
            cursor: String? = nil,

            accounts: [ComAtprotoAdminDefs.AccountView]

        ) {
            self.cursor = cursor

            self.accounts = accounts
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            cursor = try container.decodeIfPresent(String.self, forKey: .cursor)

            accounts = try container.decode([ComAtprotoAdminDefs.AccountView].self, forKey: .accounts)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)

            try container.encode(accounts, forKey: .accounts)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR

                let cursorValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "cursor", value: cursorValue)
            }

            let accountsValue = try (accounts as? DAGCBOREncodable)?.toCBORValue() ?? accounts
            map = map.adding(key: "accounts", value: accountsValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case cursor
            case accounts
        }
    }
}

public extension ATProtoClient.Tools.Ozone.Signature {
    /// Search for accounts that match one or more threat signature values.
    func searchAccounts(input: ToolsOzoneSignatureSearchAccounts.Parameters) async throws -> (responseCode: Int, data: ToolsOzoneSignatureSearchAccounts.Output?) {
        let endpoint = "tools.ozone.signature.searchAccounts"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest)
        let responseCode = response.statusCode

        // Content-Type validation
        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        // Data decoding and validation

        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(ToolsOzoneSignatureSearchAccounts.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
