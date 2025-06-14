import Foundation

// lexicon: 1, id: app.bsky.labeler.getServices

public enum AppBskyLabelerGetServices {
    public static let typeIdentifier = "app.bsky.labeler.getServices"
    public struct Parameters: Parametrizable {
        public let dids: [DID]
        public let detailed: Bool?

        public init(
            dids: [DID],
            detailed: Bool? = nil
        ) {
            self.dids = dids
            self.detailed = detailed
        }
    }

    public struct Output: ATProtocolCodable {
        public let views: [OutputViewsUnion]

        // Standard public initializer
        public init(
            views: [OutputViewsUnion]

        ) {
            self.views = views
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            views = try container.decode([OutputViewsUnion].self, forKey: .views)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(views, forKey: .views)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let viewsValue = try views.toCBORValue()
            map = map.adding(key: "views", value: viewsValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case views
        }
    }

    public enum OutputViewsUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case appBskyLabelerDefsLabelerView(AppBskyLabelerDefs.LabelerView)
        case appBskyLabelerDefsLabelerViewDetailed(AppBskyLabelerDefs.LabelerViewDetailed)
        case unexpected(ATProtocolValueContainer)

        public init(_ value: AppBskyLabelerDefs.LabelerView) {
            self = .appBskyLabelerDefsLabelerView(value)
        }

        public init(_ value: AppBskyLabelerDefs.LabelerViewDetailed) {
            self = .appBskyLabelerDefsLabelerViewDetailed(value)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            switch typeValue {
            case "app.bsky.labeler.defs#labelerView":
                let value = try AppBskyLabelerDefs.LabelerView(from: decoder)
                self = .appBskyLabelerDefsLabelerView(value)
            case "app.bsky.labeler.defs#labelerViewDetailed":
                let value = try AppBskyLabelerDefs.LabelerViewDetailed(from: decoder)
                self = .appBskyLabelerDefsLabelerViewDetailed(value)
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .appBskyLabelerDefsLabelerView(value):
                try container.encode("app.bsky.labeler.defs#labelerView", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyLabelerDefsLabelerViewDetailed(value):
                try container.encode("app.bsky.labeler.defs#labelerViewDetailed", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .appBskyLabelerDefsLabelerView(value):
                hasher.combine("app.bsky.labeler.defs#labelerView")
                hasher.combine(value)
            case let .appBskyLabelerDefsLabelerViewDetailed(value):
                hasher.combine("app.bsky.labeler.defs#labelerViewDetailed")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: OutputViewsUnion, rhs: OutputViewsUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .appBskyLabelerDefsLabelerView(lhsValue),
                .appBskyLabelerDefsLabelerView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyLabelerDefsLabelerViewDetailed(lhsValue),
                .appBskyLabelerDefsLabelerViewDetailed(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? OutputViewsUnion else { return false }
            return self == other
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .appBskyLabelerDefsLabelerView(value):
                map = map.adding(key: "$type", value: "app.bsky.labeler.defs#labelerView")

                let valueDict = try value.toCBORValue()

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
                return map
            case let .appBskyLabelerDefsLabelerViewDetailed(value):
                map = map.adding(key: "$type", value: "app.bsky.labeler.defs#labelerViewDetailed")

                let valueDict = try value.toCBORValue()

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
                return map
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .appBskyLabelerDefsLabelerView(value):
                return value.hasPendingData
            case let .appBskyLabelerDefsLabelerViewDetailed(value):
                return value.hasPendingData
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .appBskyLabelerDefsLabelerView(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .appBskyLabelerDefsLabelerView(value)
            case var .appBskyLabelerDefsLabelerViewDetailed(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .appBskyLabelerDefsLabelerViewDetailed(value)
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }
}

public extension ATProtoClient.App.Bsky.Labeler {
    // MARK: - getServices

    /// Get information about a list of labeler services.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getServices(input: AppBskyLabelerGetServices.Parameters) async throws -> (responseCode: Int, data: AppBskyLabelerGetServices.Output?) {
        let endpoint = "app.bsky.labeler.getServices"

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

        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(AppBskyLabelerGetServices.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
