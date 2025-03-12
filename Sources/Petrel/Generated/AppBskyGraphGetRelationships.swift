import Foundation
import ZippyJSON

// lexicon: 1, id: app.bsky.graph.getRelationships

public struct AppBskyGraphGetRelationships {
    public static let typeIdentifier = "app.bsky.graph.getRelationships"
    public struct Parameters: Parametrizable {
        public let actor: String
        public let others: [String]?

        public init(
            actor: String,
            others: [String]? = nil
        ) {
            self.actor = actor
            self.others = others
        }
    }

    public struct Output: ATProtocolCodable {
        public let actor: String?

        public let relationships: [OutputRelationshipsUnion]

        // Standard public initializer
        public init(
            actor: String? = nil,

            relationships: [OutputRelationshipsUnion]

        ) {
            self.actor = actor

            self.relationships = relationships
        }
    }

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case actorNotFound = "ActorNotFound.the primary actor at-identifier could not be resolved"
        public var description: String {
            return rawValue
        }
    }

    public enum OutputRelationshipsUnion: Codable, ATProtocolCodable, ATProtocolValue {
        case appBskyGraphDefsRelationship(AppBskyGraphDefs.Relationship)
        case appBskyGraphDefsNotFoundActor(AppBskyGraphDefs.NotFoundActor)
        case unexpected(ATProtocolValueContainer)

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            switch typeValue {
            case "app.bsky.graph.defs#relationship":
                let value = try AppBskyGraphDefs.Relationship(from: decoder)
                self = .appBskyGraphDefsRelationship(value)
            case "app.bsky.graph.defs#notFoundActor":
                let value = try AppBskyGraphDefs.NotFoundActor(from: decoder)
                self = .appBskyGraphDefsNotFoundActor(value)
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .appBskyGraphDefsRelationship(value):
                try container.encode("app.bsky.graph.defs#relationship", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyGraphDefsNotFoundActor(value):
                try container.encode("app.bsky.graph.defs#notFoundActor", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(ATProtocolValueContainer):
                try ATProtocolValueContainer.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .appBskyGraphDefsRelationship(value):
                hasher.combine("app.bsky.graph.defs#relationship")
                hasher.combine(value)
            case let .appBskyGraphDefsNotFoundActor(value):
                hasher.combine("app.bsky.graph.defs#notFoundActor")
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
            guard let otherValue = other as? OutputRelationshipsUnion else { return false }

            switch (self, otherValue) {
            case let (
                .appBskyGraphDefsRelationship(selfValue),
                .appBskyGraphDefsRelationship(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .appBskyGraphDefsNotFoundActor(selfValue),
                .appBskyGraphDefsNotFoundActor(otherValue)
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

public extension ATProtoClient.App.Bsky.Graph {
    /// Enumerates public relationships between one account, and a list of other accounts. Does not require auth.
    func getRelationships(input: AppBskyGraphGetRelationships.Parameters) async throws -> (responseCode: Int, data: AppBskyGraphGetRelationships.Output?) {
        let endpoint = "app.bsky.graph.getRelationships"

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
        let decodedData = try? decoder.decode(AppBskyGraphGetRelationships.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
