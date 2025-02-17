import Foundation
import ZippyJSON

// lexicon: 1, id: tools.ozone.setting.listOptions

public enum ToolsOzoneSettingListOptions {
    public static let typeIdentifier = "tools.ozone.setting.listOptions"
    public struct Parameters: Parametrizable {
        public let limit: Int?
        public let cursor: String?
        public let scope: String?
        public let prefix: String?
        public let keys: [String]?

        public init(
            limit: Int? = nil,
            cursor: String? = nil,
            scope: String? = nil,
            prefix: String? = nil,
            keys: [String]? = nil
        ) {
            self.limit = limit
            self.cursor = cursor
            self.scope = scope
            self.prefix = prefix
            self.keys = keys
        }
    }

    public struct Output: ATProtocolCodable {
        public let cursor: String?

        public let options: [ToolsOzoneSettingDefs.Option]

        // Standard public initializer
        public init(
            cursor: String? = nil,

            options: [ToolsOzoneSettingDefs.Option]

        ) {
            self.cursor = cursor

            self.options = options
        }
    }
}

public extension ATProtoClient.Tools.Ozone.Setting {
    /// List settings with optional filtering
    func listOptions(input: ToolsOzoneSettingListOptions.Parameters) async throws -> (responseCode: Int, data: ToolsOzoneSettingListOptions.Output?) {
        let endpoint = "tools.ozone.setting.listOptions"

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

        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(ToolsOzoneSettingListOptions.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
