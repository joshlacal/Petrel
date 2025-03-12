import Foundation
import ZippyJSON

// lexicon: 1, id: tools.ozone.setting.upsertOption

public enum ToolsOzoneSettingUpsertOption {
    public static let typeIdentifier = "tools.ozone.setting.upsertOption"
    public struct Input: ATProtocolCodable {
        public let key: String
        public let scope: String
        public let value: ATProtocolValueContainer
        public let description: String?
        public let managerRole: String?

        // Standard public initializer
        public init(key: String, scope: String, value: ATProtocolValueContainer, description: String? = nil, managerRole: String? = nil) {
            self.key = key
            self.scope = scope
            self.value = value
            self.description = description
            self.managerRole = managerRole
        }
    }

    public struct Output: ATProtocolCodable {
        public let option: ToolsOzoneSettingDefs.Option

        // Standard public initializer
        public init(
            option: ToolsOzoneSettingDefs.Option

        ) {
            self.option = option
        }
    }
}

public extension ATProtoClient.Tools.Ozone.Setting {
    /// Create or update setting option
    func upsertOption(
        input: ToolsOzoneSettingUpsertOption.Input

    ) async throws -> (responseCode: Int, data: ToolsOzoneSettingUpsertOption.Output?) {
        let endpoint = "tools.ozone.setting.upsertOption"

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

        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(ToolsOzoneSettingUpsertOption.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
