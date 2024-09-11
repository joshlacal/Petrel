import Foundation
internal import ZippyJSON

// lexicon: 1, id: app.bsky.labeler.getServices

public struct AppBskyLabelerGetServices {
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

    public enum OutputViewsUnion: Codable, ATProtocolCodable, ATProtocolValue {
        case appBskyLabelerDefsLabelerView(AppBskyLabelerDefs.LabelerView)
        case appBskyLabelerDefsLabelerViewDetailed(AppBskyLabelerDefs.LabelerViewDetailed)
        case unexpected(ATProtocolValueContainer)

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)
            LogManager.logDebug("OutputViewsUnion decoding: \(typeValue)")

            switch typeValue {
            case "app.bsky.labeler.defs#labelerView":
                LogManager.logDebug("Decoding as app.bsky.labeler.defs#labelerView")
                let value = try AppBskyLabelerDefs.LabelerView(from: decoder)
                self = .appBskyLabelerDefsLabelerView(value)
            case "app.bsky.labeler.defs#labelerViewDetailed":
                LogManager.logDebug("Decoding as app.bsky.labeler.defs#labelerViewDetailed")
                let value = try AppBskyLabelerDefs.LabelerViewDetailed(from: decoder)
                self = .appBskyLabelerDefsLabelerViewDetailed(value)
            default:
                LogManager.logDebug("OutputViewsUnion decoding encountered an unexpected type: \(typeValue)")
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .appBskyLabelerDefsLabelerView(value):
                LogManager.logDebug("Encoding app.bsky.labeler.defs#labelerView")
                try container.encode("app.bsky.labeler.defs#labelerView", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyLabelerDefsLabelerViewDetailed(value):
                LogManager.logDebug("Encoding app.bsky.labeler.defs#labelerViewDetailed")
                try container.encode("app.bsky.labeler.defs#labelerViewDetailed", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(ATProtocolValueContainer):
                LogManager.logDebug("OutputViewsUnion encoding unexpected value")
                try ATProtocolValueContainer.encode(to: encoder)
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
            case let .unexpected(ATProtocolValueContainer):
                hasher.combine("unexpected")
                hasher.combine(ATProtocolValueContainer)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let otherValue = other as? OutputViewsUnion else { return false }

            switch (self, otherValue) {
            case let (.appBskyLabelerDefsLabelerView(selfValue),
                      .appBskyLabelerDefsLabelerView(otherValue)):
                return selfValue == otherValue
            case let (.appBskyLabelerDefsLabelerViewDetailed(selfValue),
                      .appBskyLabelerDefsLabelerViewDetailed(otherValue)):
                return selfValue == otherValue
            case let (.unexpected(selfValue), .unexpected(otherValue)):
                return selfValue.isEqual(to: otherValue)
            default:
                return false
            }
        }
    }
}

public extension ATProtoClient.App.Bsky.Labeler {
    /// Get information about a list of labeler services.
    func getServices(input: AppBskyLabelerGetServices.Parameters) async throws -> (responseCode: Int, data: AppBskyLabelerGetServices.Output?) {
        let endpoint = "/app.bsky.labeler.getServices"

        let queryItems = input.asQueryItems()
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: [:],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest, retryCount: 0, duringInitialSetup: false)
        let responseCode = response.statusCode

        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(AppBskyLabelerGetServices.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
