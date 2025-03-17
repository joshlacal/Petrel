import Foundation

// lexicon: 1, id: app.bsky.labeler.getServices

public enum AppBskyLabelerGetServices {
    public static let typeIdentifier = "app.bsky.labeler.getServices"
    public struct Parameters: Parametrizable {
        public let dids: [String]
        public let detailed: Bool?

        public init(
            dids: [String],
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
    }

    public enum OutputViewsUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, PendingDataLoadable, Equatable {
        case appBskyLabelerDefsLabelerView(AppBskyLabelerDefs.LabelerView)
        case appBskyLabelerDefsLabelerViewDetailed(AppBskyLabelerDefs.LabelerViewDetailed)
        case unexpected(ATProtocolValueContainer)

        public static func appBskyLabelerDefsLabelerView(_ value: AppBskyLabelerDefs.LabelerView) -> OutputViewsUnion {
            return .appBskyLabelerDefsLabelerView(value)
        }

        public static func appBskyLabelerDefsLabelerViewDetailed(_ value: AppBskyLabelerDefs.LabelerViewDetailed) -> OutputViewsUnion {
            return .appBskyLabelerDefsLabelerViewDetailed(value)
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

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .appBskyLabelerDefsLabelerView(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .appBskyLabelerDefsLabelerViewDetailed(value):
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
            case var .appBskyLabelerDefsLabelerView(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? AppBskyLabelerDefs.LabelerView {
                            self = .appBskyLabelerDefsLabelerView(updatedValue)
                        }
                    }
                }
            case var .appBskyLabelerDefsLabelerViewDetailed(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? AppBskyLabelerDefs.LabelerViewDetailed {
                            self = .appBskyLabelerDefsLabelerViewDetailed(updatedValue)
                        }
                    }
                }
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }
}

public extension ATProtoClient.App.Bsky.Labeler {
    /// Get information about a list of labeler services.
    func getServices(input: AppBskyLabelerGetServices.Parameters) async throws -> (responseCode: Int, data: AppBskyLabelerGetServices.Output?) {
        let endpoint = "app.bsky.labeler.getServices"

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
        let decodedData = try? decoder.decode(AppBskyLabelerGetServices.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
