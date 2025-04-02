import Foundation

// lexicon: 1, id: com.atproto.server.createInviteCodes

public enum ComAtprotoServerCreateInviteCodes {
    public static let typeIdentifier = "com.atproto.server.createInviteCodes"

    public struct AccountCodes: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "com.atproto.server.createInviteCodes#accountCodes"
        public let account: String
        public let codes: [String]

        // Standard initializer
        public init(
            account: String, codes: [String]
        ) {
            self.account = account
            self.codes = codes
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                account = try container.decode(String.self, forKey: .account)

            } catch {
                LogManager.logError("Decoding error for property 'account': \(error)")
                throw error
            }
            do {
                codes = try container.decode([String].self, forKey: .codes)

            } catch {
                LogManager.logError("Decoding error for property 'codes': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(account, forKey: .account)

            try container.encode(codes, forKey: .codes)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(account)
            hasher.combine(codes)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if account != other.account {
                return false
            }

            if codes != other.codes {
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

            let codesValue = try (codes as? DAGCBOREncodable)?.toCBORValue() ?? codes
            map = map.adding(key: "codes", value: codesValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case account
            case codes
        }
    }

    public struct Input: ATProtocolCodable {
        public let codeCount: Int
        public let useCount: Int
        public let forAccounts: [DID]?

        // Standard public initializer
        public init(codeCount: Int, useCount: Int, forAccounts: [DID]? = nil) {
            self.codeCount = codeCount
            self.useCount = useCount
            self.forAccounts = forAccounts
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            codeCount = try container.decode(Int.self, forKey: .codeCount)

            useCount = try container.decode(Int.self, forKey: .useCount)

            forAccounts = try container.decodeIfPresent([DID].self, forKey: .forAccounts)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(codeCount, forKey: .codeCount)

            try container.encode(useCount, forKey: .useCount)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(forAccounts, forKey: .forAccounts)
        }

        private enum CodingKeys: String, CodingKey {
            case codeCount
            case useCount
            case forAccounts
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let codeCountValue = try (codeCount as? DAGCBOREncodable)?.toCBORValue() ?? codeCount
            map = map.adding(key: "codeCount", value: codeCountValue)

            let useCountValue = try (useCount as? DAGCBOREncodable)?.toCBORValue() ?? useCount
            map = map.adding(key: "useCount", value: useCountValue)

            if let value = forAccounts {
                // Encode optional property even if it's an empty array for CBOR

                let forAccountsValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "forAccounts", value: forAccountsValue)
            }

            return map
        }
    }

    public struct Output: ATProtocolCodable {
        public let codes: [AccountCodes]

        // Standard public initializer
        public init(
            codes: [AccountCodes]

        ) {
            self.codes = codes
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            codes = try container.decode([AccountCodes].self, forKey: .codes)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(codes, forKey: .codes)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let codesValue = try (codes as? DAGCBOREncodable)?.toCBORValue() ?? codes
            map = map.adding(key: "codes", value: codesValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case codes
        }
    }
}

public extension ATProtoClient.Com.Atproto.Server {
    /// Create invite codes.
    func createInviteCodes(
        input: ComAtprotoServerCreateInviteCodes.Input

    ) async throws -> (responseCode: Int, data: ComAtprotoServerCreateInviteCodes.Output?) {
        let endpoint = "com.atproto.server.createInviteCodes"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        headers["Accept"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
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
        let decodedData = try? decoder.decode(ComAtprotoServerCreateInviteCodes.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
