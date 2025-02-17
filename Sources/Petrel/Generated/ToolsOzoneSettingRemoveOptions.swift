import Foundation
import ZippyJSON

// lexicon: 1, id: tools.ozone.setting.removeOptions

public enum ToolsOzoneSettingRemoveOptions {
    public static let typeIdentifier = "tools.ozone.setting.removeOptions"
    public struct Input: ATProtocolCodable {
        public let keys: [String]
        public let scope: String

        // Standard public initializer
        public init(keys: [String], scope: String) {
            self.keys = keys
            self.scope = scope
        }
    }

    public struct Output: ATProtocolCodable {
        public let data: Data

        // Standard public initializer
        public init(
            data: Data

        ) {
            self.data = data
        }
    }
}

public extension ATProtoClient.Tools.Ozone.Setting {
    /// Delete settings by key
    func removeOptions(
        input: ToolsOzoneSettingRemoveOptions.Input

    ) async throws -> (responseCode: Int, data: ToolsOzoneSettingRemoveOptions.Output?) {
        let endpoint = "tools.ozone.setting.removeOptions"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        headers["Accept"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
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
        let decodedData = try? decoder.decode(ToolsOzoneSettingRemoveOptions.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
