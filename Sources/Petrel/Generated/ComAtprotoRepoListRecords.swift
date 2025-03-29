import Foundation

// lexicon: 1, id: com.atproto.repo.listRecords

public enum ComAtprotoRepoListRecords {
    public static let typeIdentifier = "com.atproto.repo.listRecords"

    public struct Record: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "com.atproto.repo.listRecords#record"
        public let uri: ATProtocolURI
        public let cid: CID
        public let value: ATProtocolValueContainer

        // Standard initializer
        public init(
            uri: ATProtocolURI, cid: CID, value: ATProtocolValueContainer
        ) {
            self.uri = uri
            self.cid = cid
            self.value = value
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                uri = try container.decode(ATProtocolURI.self, forKey: .uri)

            } catch {
                LogManager.logError("Decoding error for property 'uri': \(error)")
                throw error
            }
            do {
                cid = try container.decode(CID.self, forKey: .cid)

            } catch {
                LogManager.logError("Decoding error for property 'cid': \(error)")
                throw error
            }
            do {
                value = try container.decode(ATProtocolValueContainer.self, forKey: .value)

            } catch {
                LogManager.logError("Decoding error for property 'value': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(uri, forKey: .uri)

            try container.encode(cid, forKey: .cid)

            try container.encode(value, forKey: .value)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
            hasher.combine(cid)
            hasher.combine(value)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if uri != other.uri {
                return false
            }

            if cid != other.cid {
                return false
            }

            if value != other.value {
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

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            let uriValue = try (uri as? DAGCBOREncodable)?.toCBORValue() ?? uri
            map = map.adding(key: "uri", value: uriValue)

            let cidValue = try (cid as? DAGCBOREncodable)?.toCBORValue() ?? cid
            map = map.adding(key: "cid", value: cidValue)

            let valueValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
            map = map.adding(key: "value", value: valueValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
            case cid
            case value
        }
    }

    public struct Parameters: Parametrizable {
        public let repo: ATIdentifier
        public let collection: NSID
        public let limit: Int?
        public let cursor: String?
        public let reverse: Bool?

        public init(
            repo: ATIdentifier,
            collection: NSID,
            limit: Int? = nil,
            cursor: String? = nil,
            reverse: Bool? = nil
        ) {
            self.repo = repo
            self.collection = collection
            self.limit = limit
            self.cursor = cursor
            self.reverse = reverse
        }
    }

    public struct Output: ATProtocolCodable {
        public let cursor: String?

        public let records: [Record]

        // Standard public initializer
        public init(
            cursor: String? = nil,

            records: [Record]

        ) {
            self.cursor = cursor

            self.records = records
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            cursor = try container.decodeIfPresent(String.self, forKey: .cursor)

            records = try container.decode([Record].self, forKey: .records)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            if let value = cursor {
                try container.encode(value, forKey: .cursor)
            }

            try container.encode(records, forKey: .records)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Add fields in lexicon-defined order

            if let value = cursor {
                let cursorValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "cursor", value: cursorValue)
            }

            let recordsValue = try (records as? DAGCBOREncodable)?.toCBORValue() ?? records
            map = map.adding(key: "records", value: recordsValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case cursor
            case records
        }
    }
}

public extension ATProtoClient.Com.Atproto.Repo {
    /// List a range of records in a repository, matching a specific collection. Does not require auth.
    func listRecords(input: ComAtprotoRepoListRecords.Parameters) async throws -> (responseCode: Int, data: ComAtprotoRepoListRecords.Output?) {
        let endpoint = "com.atproto.repo.listRecords"

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
        let decodedData = try? decoder.decode(ComAtprotoRepoListRecords.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
