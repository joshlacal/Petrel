import Foundation

// lexicon: 1, id: tools.ozone.communication.createTemplate

public enum ToolsOzoneCommunicationCreateTemplate {
    public static let typeIdentifier = "tools.ozone.communication.createTemplate"
    public struct Input: ATProtocolCodable {
        public let name: String
        public let contentMarkdown: String
        public let subject: String
        public let lang: LanguageCodeContainer?
        public let createdBy: DID?

        // Standard public initializer
        public init(name: String, contentMarkdown: String, subject: String, lang: LanguageCodeContainer? = nil, createdBy: DID? = nil) {
            self.name = name
            self.contentMarkdown = contentMarkdown
            self.subject = subject
            self.lang = lang
            self.createdBy = createdBy
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            name = try container.decode(String.self, forKey: .name)

            contentMarkdown = try container.decode(String.self, forKey: .contentMarkdown)

            subject = try container.decode(String.self, forKey: .subject)

            lang = try container.decodeIfPresent(LanguageCodeContainer.self, forKey: .lang)

            createdBy = try container.decodeIfPresent(DID.self, forKey: .createdBy)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(name, forKey: .name)

            try container.encode(contentMarkdown, forKey: .contentMarkdown)

            try container.encode(subject, forKey: .subject)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(lang, forKey: .lang)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(createdBy, forKey: .createdBy)
        }

        private enum CodingKeys: String, CodingKey {
            case name
            case contentMarkdown
            case subject
            case lang
            case createdBy
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let nameValue = try (name as? DAGCBOREncodable)?.toCBORValue() ?? name
            map = map.adding(key: "name", value: nameValue)

            let contentMarkdownValue = try (contentMarkdown as? DAGCBOREncodable)?.toCBORValue() ?? contentMarkdown
            map = map.adding(key: "contentMarkdown", value: contentMarkdownValue)

            let subjectValue = try (subject as? DAGCBOREncodable)?.toCBORValue() ?? subject
            map = map.adding(key: "subject", value: subjectValue)

            if let value = lang {
                // Encode optional property even if it's an empty array for CBOR

                let langValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "lang", value: langValue)
            }

            if let value = createdBy {
                // Encode optional property even if it's an empty array for CBOR

                let createdByValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "createdBy", value: createdByValue)
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
    /// Administrative action to create a new, re-usable communication (email for now) template.
    func createTemplate(
        input: ToolsOzoneCommunicationCreateTemplate.Input

    ) async throws -> (responseCode: Int, data: ToolsOzoneCommunicationCreateTemplate.Output?) {
        let endpoint = "tools.ozone.communication.createTemplate"

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
        let decodedData = try? decoder.decode(ToolsOzoneCommunicationCreateTemplate.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
