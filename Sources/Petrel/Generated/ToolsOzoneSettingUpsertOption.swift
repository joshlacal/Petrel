import Foundation

// lexicon: 1, id: tools.ozone.setting.upsertOption

public enum ToolsOzoneSettingUpsertOption {
    public static let typeIdentifier = "tools.ozone.setting.upsertOption"
    public struct Input: ATProtocolCodable {
        public let key: NSID
        public let scope: String
        public let value: ATProtocolValueContainer
        public let description: String?
        public let managerRole: String?

        // Standard public initializer
        public init(key: NSID, scope: String, value: ATProtocolValueContainer, description: String? = nil, managerRole: String? = nil) {
            self.key = key
            self.scope = scope
            self.value = value
            self.description = description
            self.managerRole = managerRole
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            key = try container.decode(NSID.self, forKey: .key)

            scope = try container.decode(String.self, forKey: .scope)

            value = try container.decode(ATProtocolValueContainer.self, forKey: .value)

            description = try container.decodeIfPresent(String.self, forKey: .description)

            managerRole = try container.decodeIfPresent(String.self, forKey: .managerRole)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(key, forKey: .key)

            try container.encode(scope, forKey: .scope)

            try container.encode(value, forKey: .value)

            if let value = description {
                try container.encode(value, forKey: .description)
            }

            if let value = managerRole {
                try container.encode(value, forKey: .managerRole)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case key
            case scope
            case value
            case description
            case managerRole
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Add fields in lexicon-defined order

            let keyValue = try (key as? DAGCBOREncodable)?.toCBORValue() ?? key
            map = map.adding(key: "key", value: keyValue)

            let scopeValue = try (scope as? DAGCBOREncodable)?.toCBORValue() ?? scope
            map = map.adding(key: "scope", value: scopeValue)

            let valueValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
            map = map.adding(key: "value", value: valueValue)

            if let value = description {
                let descriptionValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "description", value: descriptionValue)
            }

            if let value = managerRole {
                let managerRoleValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "managerRole", value: managerRoleValue)
            }

            return map
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

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            option = try container.decode(ToolsOzoneSettingDefs.Option.self, forKey: .option)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(option, forKey: .option)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Add fields in lexicon-defined order

            let optionValue = try (option as? DAGCBOREncodable)?.toCBORValue() ?? option
            map = map.adding(key: "option", value: optionValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case option
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
