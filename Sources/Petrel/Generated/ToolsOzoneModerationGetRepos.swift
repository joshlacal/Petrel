import Foundation

// lexicon: 1, id: tools.ozone.moderation.getRepos

public enum ToolsOzoneModerationGetRepos {
    public static let typeIdentifier = "tools.ozone.moderation.getRepos"
    public struct Parameters: Parametrizable {
        public let dids: [String]

        public init(
            dids: [String]
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

        private enum CodingKeys: String, CodingKey {
            case repos
        }
    }

    public enum OutputReposUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, PendingDataLoadable, Equatable {
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

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .toolsOzoneModerationDefsRepoViewDetail(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsRepoViewNotFound(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case let .toolsOzoneModerationDefsRepoViewDetail(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    await loadable.loadPendingData()
                    // Update the value if it was mutated (only if it's actually the expected type)
                    if let updatedValue = loadable as? ToolsOzoneModerationDefs.RepoViewDetail {
                        self = .toolsOzoneModerationDefsRepoViewDetail(updatedValue)
                    }
                }
            case let .toolsOzoneModerationDefsRepoViewNotFound(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    await loadable.loadPendingData()
                    // Update the value if it was mutated (only if it's actually the expected type)
                    if let updatedValue = loadable as? ToolsOzoneModerationDefs.RepoViewNotFound {
                        self = .toolsOzoneModerationDefsRepoViewNotFound(updatedValue)
                    }
                }
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
