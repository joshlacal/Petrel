import Foundation

// lexicon: 1, id: tools.ozone.signature.findRelatedAccounts

public enum ToolsOzoneSignatureFindRelatedAccounts {
    public static let typeIdentifier = "tools.ozone.signature.findRelatedAccounts"

    public struct RelatedAccount: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.signature.findRelatedAccounts#relatedAccount"
        public let account: ComAtprotoAdminDefs.AccountView
        public let similarities: [ToolsOzoneSignatureDefs.SigDetail]?

        // Standard initializer
        public init(
            account: ComAtprotoAdminDefs.AccountView, similarities: [ToolsOzoneSignatureDefs.SigDetail]?
        ) {
            self.account = account
            self.similarities = similarities
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                account = try container.decode(ComAtprotoAdminDefs.AccountView.self, forKey: .account)

            } catch {
                LogManager.logError("Decoding error for property 'account': \(error)")
                throw error
            }
            do {
                similarities = try container.decodeIfPresent([ToolsOzoneSignatureDefs.SigDetail].self, forKey: .similarities)

            } catch {
                LogManager.logError("Decoding error for property 'similarities': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(account, forKey: .account)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(similarities, forKey: .similarities)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(account)
            if let value = similarities {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if account != other.account {
                return false
            }

            if similarities != other.similarities {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let accountValue = try (account as? DAGCBOREncodable)?.toCBORValue() ?? account
            map = map.adding(key: "account", value: accountValue)

            if let value = similarities {
                // Encode optional property even if it's an empty array for CBOR

                let similaritiesValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "similarities", value: similaritiesValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case account
            case similarities
        }
    }

    public struct Parameters: Parametrizable {
        public let did: DID
        public let cursor: String?
        public let limit: Int?

        public init(
            did: DID,
            cursor: String? = nil,
            limit: Int? = nil
        ) {
            self.did = did
            self.cursor = cursor
            self.limit = limit
        }
    }

    public struct Output: ATProtocolCodable {
        public let cursor: String?

        public let accounts: [RelatedAccount]

        // Standard public initializer
        public init(
            cursor: String? = nil,

            accounts: [RelatedAccount]

        ) {
            self.cursor = cursor

            self.accounts = accounts
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            cursor = try container.decodeIfPresent(String.self, forKey: .cursor)

            accounts = try container.decode([RelatedAccount].self, forKey: .accounts)
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
    /// Get accounts that share some matching threat signatures with the root account.
    func findRelatedAccounts(input: ToolsOzoneSignatureFindRelatedAccounts.Parameters) async throws -> (responseCode: Int, data: ToolsOzoneSignatureFindRelatedAccounts.Output?) {
        let endpoint = "tools.ozone.signature.findRelatedAccounts"

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
        let decodedData = try? decoder.decode(ToolsOzoneSignatureFindRelatedAccounts.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
