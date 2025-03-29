import Foundation

// lexicon: 1, id: com.atproto.sync.listBlobs

public enum ComAtprotoSyncListBlobs {
    public static let typeIdentifier = "com.atproto.sync.listBlobs"
    public struct Parameters: Parametrizable {
        public let did: DID
        public let since: TID?
        public let limit: Int?
        public let cursor: String?

        public init(
            did: DID,
            since: TID? = nil,
            limit: Int? = nil,
            cursor: String? = nil
        ) {
            self.did = did
            self.since = since
            self.limit = limit
            self.cursor = cursor
        }
    }

    public struct Output: ATProtocolCodable {
        public let cursor: String?

        public let cids: [CID]

        // Standard public initializer
        public init(
            cursor: String? = nil,

            cids: [CID]

        ) {
            self.cursor = cursor

            self.cids = cids
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            cursor = try container.decodeIfPresent(String.self, forKey: .cursor)

            cids = try container.decode([CID].self, forKey: .cids)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            if let value = cursor {
                try container.encode(value, forKey: .cursor)
            }

            try container.encode(cids, forKey: .cids)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Add fields in lexicon-defined order

            if let value = cursor {
                let cursorValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "cursor", value: cursorValue)
            }

            let cidsValue = try (cids as? DAGCBOREncodable)?.toCBORValue() ?? cids
            map = map.adding(key: "cids", value: cidsValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case cursor
            case cids
        }
    }

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case repoNotFound = "RepoNotFound."
        case repoTakendown = "RepoTakendown."
        case repoSuspended = "RepoSuspended."
        case repoDeactivated = "RepoDeactivated."
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.Com.Atproto.Sync {
    /// List blob CIDs for an account, since some repo revision. Does not require auth; implemented by PDS.
    func listBlobs(input: ComAtprotoSyncListBlobs.Parameters) async throws -> (responseCode: Int, data: ComAtprotoSyncListBlobs.Output?) {
        let endpoint = "com.atproto.sync.listBlobs"

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
        let decodedData = try? decoder.decode(ComAtprotoSyncListBlobs.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
