import Foundation

// lexicon: 1, id: tools.ozone.setting.removeOptions

public enum ToolsOzoneSettingRemoveOptions {
    public static let typeIdentifier = "tools.ozone.setting.removeOptions"
    public struct Input: ATProtocolCodable {
        public let keys: [NSID]
        public let scope: String

        // Standard public initializer
        public init(keys: [NSID], scope: String) {
            self.keys = keys
            self.scope = scope
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            keys = try container.decode([NSID].self, forKey: .keys)

            scope = try container.decode(String.self, forKey: .scope)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(keys, forKey: .keys)

            try container.encode(scope, forKey: .scope)
        }

        private enum CodingKeys: String, CodingKey {
            case keys
            case scope
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let keysValue = try (keys as? DAGCBOREncodable)?.toCBORValue() ?? keys
            map = map.adding(key: "keys", value: keysValue)

            let scopeValue = try (scope as? DAGCBOREncodable)?.toCBORValue() ?? scope
            map = map.adding(key: "scope", value: scopeValue)

            return map
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

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            let data = try container.decode(Data.self, forKey: .data)
            self.data = data
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(data, forKey: .data)
        }

        public func toCBORValue() throws -> Any {
            return data
        }

        private enum CodingKeys: String, CodingKey {
            case data
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

        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(ToolsOzoneSettingRemoveOptions.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
