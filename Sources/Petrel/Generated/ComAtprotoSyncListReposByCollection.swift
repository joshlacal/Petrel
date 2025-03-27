import Foundation

// lexicon: 1, id: com.atproto.sync.listReposByCollection

public enum ComAtprotoSyncListReposByCollection {
    public static let typeIdentifier = "com.atproto.sync.listReposByCollection"

    public struct Repo: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "com.atproto.sync.listReposByCollection#repo"
        public let did: String

        // Standard initializer
        public init(
            did: String
        ) {
            self.did = did
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                did = try container.decode(String.self, forKey: .did)

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

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
        }
    }

    public struct Parameters: Parametrizable {
        public let collection: String
        public let limit: Int?
        public let cursor: String?

        public init(
            collection: String,
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

            if let value = cursor {
                try container.encode(value, forKey: .cursor)
            }

            try container.encode(repos, forKey: .repos)
        }

        private enum CodingKeys: String, CodingKey {
            case cursor
            case repos
        }
    }
}

public extension ATProtoClient.Com.Atproto.Sync {
    /// Enumerates all the DIDs which have records with the given collection NSID.
    func listReposByCollection(input: ComAtprotoSyncListReposByCollection.Parameters) async throws -> (responseCode: Int, data: ComAtprotoSyncListReposByCollection.Output?) {
        let endpoint = "com.atproto.sync.listReposByCollection"

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
        let decodedData = try? decoder.decode(ComAtprotoSyncListReposByCollection.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
