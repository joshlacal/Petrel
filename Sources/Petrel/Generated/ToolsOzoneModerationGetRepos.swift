import Foundation

// lexicon: 1, id: tools.ozone.moderation.getRepos

public enum ToolsOzoneModerationGetRepos {
    public static let typeIdentifier = "tools.ozone.moderation.getRepos"
    public struct Parameters: Parametrizable {
        public let dids: [DID]

        public init(
            dids: [DID]
        ) {
            self.dids = dids
        }
    }

    public struct Output: ATProtocolCodable {
        public let repos: [OutputReposUnion]

        // Standard public initializer
        public init(
            repos: [OutputReposUnion]

        ) {
            self.repos = repos
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            repos = try container.decode([OutputReposUnion].self, forKey: .repos)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(repos, forKey: .repos)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let reposValue = try (repos as? DAGCBOREncodable)?.toCBORValue() ?? repos
            map = map.adding(key: "repos", value: reposValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case repos
        }
    }

    public enum OutputReposUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case toolsOzoneModerationDefsRepoViewDetail(ToolsOzoneModerationDefs.RepoViewDetail)
        case toolsOzoneModerationDefsRepoViewNotFound(ToolsOzoneModerationDefs.RepoViewNotFound)
        case unexpected(ATProtocolValueContainer)

        public init(_ value: ToolsOzoneModerationDefs.RepoViewDetail) {
            self = .toolsOzoneModerationDefsRepoViewDetail(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.RepoViewNotFound) {
            self = .toolsOzoneModerationDefsRepoViewNotFound(value)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            switch typeValue {
            case "tools.ozone.moderation.defs#repoViewDetail":
                let value = try ToolsOzoneModerationDefs.RepoViewDetail(from: decoder)
                self = .toolsOzoneModerationDefsRepoViewDetail(value)
            case "tools.ozone.moderation.defs#repoViewNotFound":
                let value = try ToolsOzoneModerationDefs.RepoViewNotFound(from: decoder)
                self = .toolsOzoneModerationDefsRepoViewNotFound(value)
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .toolsOzoneModerationDefsRepoViewDetail(value):
                try container.encode("tools.ozone.moderation.defs#repoViewDetail", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsRepoViewNotFound(value):
                try container.encode("tools.ozone.moderation.defs#repoViewNotFound", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .toolsOzoneModerationDefsRepoViewDetail(value):
                hasher.combine("tools.ozone.moderation.defs#repoViewDetail")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsRepoViewNotFound(value):
                hasher.combine("tools.ozone.moderation.defs#repoViewNotFound")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: OutputReposUnion, rhs: OutputReposUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .toolsOzoneModerationDefsRepoViewDetail(lhsValue),
                .toolsOzoneModerationDefsRepoViewDetail(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsRepoViewNotFound(lhsValue),
                .toolsOzoneModerationDefsRepoViewNotFound(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? OutputReposUnion else { return false }
            return self == other
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .toolsOzoneModerationDefsRepoViewDetail(value):
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#repoViewDetail")

                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsRepoViewNotFound(value):
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#repoViewNotFound")

                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .toolsOzoneModerationDefsRepoViewDetail(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsRepoViewNotFound(value):
                return value.hasPendingData
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .toolsOzoneModerationDefsRepoViewDetail(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsRepoViewDetail(value)
            case var .toolsOzoneModerationDefsRepoViewNotFound(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsRepoViewNotFound(value)
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }
}

public extension ATProtoClient.Tools.Ozone.Moderation {
    /// Get details about some repositories.
    func getRepos(input: ToolsOzoneModerationGetRepos.Parameters) async throws -> (responseCode: Int, data: ToolsOzoneModerationGetRepos.Output?) {
        let endpoint = "tools.ozone.moderation.getRepos"

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
        let decodedData = try? decoder.decode(ToolsOzoneModerationGetRepos.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
