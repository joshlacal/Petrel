import Foundation
import ZippyJSON

// lexicon: 1, id: tools.ozone.moderation.getRepos

public struct ToolsOzoneModerationGetRepos {
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
    }

    public enum OutputReposUnion: Codable, ATProtocolCodable, ATProtocolValue {
        case toolsOzoneModerationDefsRepoViewDetail(ToolsOzoneModerationDefs.RepoViewDetail)
        case toolsOzoneModerationDefsRepoViewNotFound(ToolsOzoneModerationDefs.RepoViewNotFound)
        case unexpected(ATProtocolValueContainer)

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
            case let .unexpected(ATProtocolValueContainer):
                try ATProtocolValueContainer.encode(to: encoder)
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
            case let .unexpected(ATProtocolValueContainer):
                hasher.combine("unexpected")
                hasher.combine(ATProtocolValueContainer)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let otherValue = other as? OutputReposUnion else { return false }

            switch (self, otherValue) {
            case let (
                .toolsOzoneModerationDefsRepoViewDetail(selfValue),
                .toolsOzoneModerationDefsRepoViewDetail(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .toolsOzoneModerationDefsRepoViewNotFound(selfValue),
                .toolsOzoneModerationDefsRepoViewNotFound(otherValue)
            ):
                return selfValue == otherValue
            case let (.unexpected(selfValue), .unexpected(otherValue)):
                return selfValue.isEqual(to: otherValue)
            default:
                return false
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
