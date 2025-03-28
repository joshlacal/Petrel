import Foundation

// lexicon: 1, id: tools.ozone.communication.updateTemplate

public enum ToolsOzoneCommunicationUpdateTemplate {
    public static let typeIdentifier = "tools.ozone.communication.updateTemplate"
    public struct Input: ATProtocolCodable {
        public let id: String
        public let name: String?
        public let lang: LanguageCodeContainer?
        public let contentMarkdown: String?
        public let subject: String?
        public let updatedBy: DID?
        public let disabled: Bool?

        // Standard public initializer
        public init(id: String, name: String? = nil, lang: LanguageCodeContainer? = nil, contentMarkdown: String? = nil, subject: String? = nil, updatedBy: DID? = nil, disabled: Bool? = nil) {
            self.id = id
            self.name = name
            self.lang = lang
            self.contentMarkdown = contentMarkdown
            self.subject = subject
            self.updatedBy = updatedBy
            self.disabled = disabled
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            id = try container.decode(String.self, forKey: .id)

            name = try container.decodeIfPresent(String.self, forKey: .name)

            lang = try container.decodeIfPresent(LanguageCodeContainer.self, forKey: .lang)

            contentMarkdown = try container.decodeIfPresent(String.self, forKey: .contentMarkdown)

            subject = try container.decodeIfPresent(String.self, forKey: .subject)

            updatedBy = try container.decodeIfPresent(DID.self, forKey: .updatedBy)

            disabled = try container.decodeIfPresent(Bool.self, forKey: .disabled)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(id, forKey: .id)

            if let value = name {
                try container.encode(value, forKey: .name)
            }

            if let value = lang {
                try container.encode(value, forKey: .lang)
            }

            if let value = contentMarkdown {
                try container.encode(value, forKey: .contentMarkdown)
            }

            if let value = subject {
                try container.encode(value, forKey: .subject)
            }

            if let value = updatedBy {
                try container.encode(value, forKey: .updatedBy)
            }

            if let value = disabled {
                try container.encode(value, forKey: .disabled)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case id
            case name
            case lang
            case contentMarkdown
            case subject
            case updatedBy
            case disabled
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Add fields in lexicon-defined order

            let idValue = try (id as? DAGCBOREncodable)?.toCBORValue() ?? id
            map = map.adding(key: "id", value: idValue)

            if let value = name {
                let nameValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "name", value: nameValue)
            }

            if let value = lang {
                let langValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "lang", value: langValue)
            }

            if let value = contentMarkdown {
                let contentMarkdownValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "contentMarkdown", value: contentMarkdownValue)
            }

            if let value = subject {
                let subjectValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "subject", value: subjectValue)
            }

            if let value = updatedBy {
                let updatedByValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "updatedBy", value: updatedByValue)
            }

            if let value = disabled {
                let disabledValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "disabled", value: disabledValue)
            }

            return map
        }
    }

    public typealias Output = ToolsOzoneCommunicationDefs.TemplateView

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case duplicateTemplateName = "DuplicateTemplateName."
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.Tools.Ozone.Communication {
    /// Administrative action to update an existing communication template. Allows passing partial fields to patch specific fields only.
    func updateTemplate(
        input: ToolsOzoneCommunicationUpdateTemplate.Input

    ) async throws -> (responseCode: Int, data: ToolsOzoneCommunicationUpdateTemplate.Output?) {
        let endpoint = "tools.ozone.communication.updateTemplate"

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
        let decodedData = try? decoder.decode(ToolsOzoneCommunicationUpdateTemplate.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
