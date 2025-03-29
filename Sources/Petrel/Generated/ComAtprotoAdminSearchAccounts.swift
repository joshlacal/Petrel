import Foundation

// lexicon: 1, id: com.atproto.admin.searchAccounts

public enum ComAtprotoAdminSearchAccounts {
    public static let typeIdentifier = "com.atproto.admin.searchAccounts"
    public struct Parameters: Parametrizable {
        public let email: String?
        public let cursor: String?
        public let limit: Int?

        public init(
            email: String? = nil,
            cursor: String? = nil,
            limit: Int? = nil
        ) {
            self.email = email
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

            if let value = cursor {
                try container.encode(value, forKey: .cursor)
            }

            try container.encode(accounts, forKey: .accounts)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Add fields in lexicon-defined order

            if let value = cursor {
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

public extension ATProtoClient.Com.Atproto.Admin {
    /// Get list of accounts that matches your search query.
    func searchAccounts(input: ComAtprotoAdminSearchAccounts.Parameters) async throws -> (responseCode: Int, data: ComAtprotoAdminSearchAccounts.Output?) {
        let endpoint = "com.atproto.admin.searchAccounts"

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
        let decodedData = try? decoder.decode(ComAtprotoAdminSearchAccounts.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
