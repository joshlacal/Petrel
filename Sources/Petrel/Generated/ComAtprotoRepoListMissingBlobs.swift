import Foundation

// lexicon: 1, id: com.atproto.repo.listMissingBlobs

public enum ComAtprotoRepoListMissingBlobs {
    public static let typeIdentifier = "com.atproto.repo.listMissingBlobs"

    public struct RecordBlob: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "com.atproto.repo.listMissingBlobs#recordBlob"
        public let cid: CID
        public let recordUri: ATProtocolURI

        // Standard initializer
        public init(
            cid: CID, recordUri: ATProtocolURI
        ) {
            self.cid = cid
            self.recordUri = recordUri
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                cid = try container.decode(CID.self, forKey: .cid)

            } catch {
                LogManager.logError("Decoding error for property 'cid': \(error)")
                throw error
            }
            do {
                recordUri = try container.decode(ATProtocolURI.self, forKey: .recordUri)

            } catch {
                LogManager.logError("Decoding error for property 'recordUri': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(cid, forKey: .cid)

            try container.encode(recordUri, forKey: .recordUri)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(cid)
            hasher.combine(recordUri)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if cid != other.cid {
                return false
            }

            if recordUri != other.recordUri {
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

            let cidValue = try (cid as? DAGCBOREncodable)?.toCBORValue() ?? cid
            map = map.adding(key: "cid", value: cidValue)

            let recordUriValue = try (recordUri as? DAGCBOREncodable)?.toCBORValue() ?? recordUri
            map = map.adding(key: "recordUri", value: recordUriValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case cid
            case recordUri
        }
    }

    public struct Parameters: Parametrizable {
        public let limit: Int?
        public let cursor: String?

        public init(
            limit: Int? = nil,
            cursor: String? = nil
        ) {
            self.limit = limit
            self.cursor = cursor
        }
    }

    public struct Output: ATProtocolCodable {
        public let cursor: String?

        public let blobs: [RecordBlob]

        // Standard public initializer
        public init(
            cursor: String? = nil,

            blobs: [RecordBlob]

        ) {
            self.cursor = cursor

            self.blobs = blobs
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            cursor = try container.decodeIfPresent(String.self, forKey: .cursor)

            blobs = try container.decode([RecordBlob].self, forKey: .blobs)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            if let value = cursor {
                try container.encode(value, forKey: .cursor)
            }

            try container.encode(blobs, forKey: .blobs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Add fields in lexicon-defined order

            if let value = cursor {
                let cursorValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "cursor", value: cursorValue)
            }

            let blobsValue = try (blobs as? DAGCBOREncodable)?.toCBORValue() ?? blobs
            map = map.adding(key: "blobs", value: blobsValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case cursor
            case blobs
        }
    }
}

public extension ATProtoClient.Com.Atproto.Repo {
    /// Returns a list of missing blobs for the requesting account. Intended to be used in the account migration flow.
    func listMissingBlobs(input: ComAtprotoRepoListMissingBlobs.Parameters) async throws -> (responseCode: Int, data: ComAtprotoRepoListMissingBlobs.Output?) {
        let endpoint = "com.atproto.repo.listMissingBlobs"

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
        let decodedData = try? decoder.decode(ComAtprotoRepoListMissingBlobs.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
