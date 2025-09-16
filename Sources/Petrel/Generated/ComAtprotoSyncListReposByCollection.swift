import Foundation

// lexicon: 1, id: com.atproto.sync.listReposByCollection

public enum ComAtprotoSyncListReposByCollection {
    public static let typeIdentifier = "com.atproto.sync.listReposByCollection"

    public struct Repo: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "com.atproto.sync.listReposByCollection#repo"
        public let did: DID

        // Standard initializer
        public init(
            did: DID
        ) {
            self.did = did
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                did = try container.decode(DID.self, forKey: .did)

            } catch {
                LogManager.logError("Decoding error for property 'did': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(did, forKey: .did)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(did)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if did != other.did {
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

            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
        }
    }

    public struct Parameters: Parametrizable {
        public let collection: NSID
        public let limit: Int?
        public let cursor: String?

        public init(
            collection: NSID,
            limit: Int? = nil,
            cursor: String? = nil
        ) {
            self.collection = collection
            self.limit = limit
            self.cursor = cursor
        }
    }

    public struct Output: ATProtocolCodable {
        public let cursor: String?

        public let repos: [Repo]

        // Standard public initializer
        public init(
            cursor: String? = nil,

            repos: [Repo]

        ) {
            self.cursor = cursor

            self.repos = repos
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            cursor = try container.decodeIfPresent(String.self, forKey: .cursor)

            repos = try container.decode([Repo].self, forKey: .repos)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)

            try container.encode(repos, forKey: .repos)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR
                let cursorValue = try value.toCBORValue()
                map = map.adding(key: "cursor", value: cursorValue)
            }

            let reposValue = try repos.toCBORValue()
            map = map.adding(key: "repos", value: reposValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case cursor
            case repos
        }
    }
}

public extension ATProtoClient.Com.Atproto.Sync {
    // MARK: - listReposByCollection

    /// Enumerates all the DIDs which have records with the given collection NSID.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func listReposByCollection(input: ComAtprotoSyncListReposByCollection.Parameters) async throws -> (responseCode: Int, data: ComAtprotoSyncListReposByCollection.Output?) {
        let endpoint = "com.atproto.sync.listReposByCollection"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkService.performRequest(urlRequest)

        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        // Only decode response data if request was successful
        if (200 ... 299).contains(responseCode) {
            do {
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(ComAtprotoSyncListReposByCollection.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for com.atproto.sync.listReposByCollection: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
