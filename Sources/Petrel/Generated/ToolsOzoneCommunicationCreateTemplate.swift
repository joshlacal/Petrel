import Foundation
internal import ZippyJSON

// lexicon: 1, id: tools.ozone.communication.createTemplate

public enum ToolsOzoneCommunicationCreateTemplate {
    public static let typeIdentifier = "tools.ozone.communication.createTemplate"
    public struct Input: ATProtocolCodable {
        public let name: String
        public let contentMarkdown: String
        public let subject: String
        public let lang: LanguageCodeContainer?
        public let createdBy: String?

        // Standard public initializer
        public init(name: String, contentMarkdown: String, subject: String, lang: LanguageCodeContainer? = nil, createdBy: String? = nil) {
            self.name = name
            self.contentMarkdown = contentMarkdown
            self.subject = subject
            self.lang = lang
            self.createdBy = createdBy
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
        input: ToolsOzoneCommunicationCreateTemplate.Input,

        duringInitialSetup: Bool = false
    ) async throws -> (responseCode: Int, data: ToolsOzoneCommunicationCreateTemplate.Output?) {
        let endpoint = "/tools.ozone.communication.createTemplate"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: ["Content-Type": "application/json"],
            body: requestData,
            queryItems: nil
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest, retryCount: 0, duringInitialSetup: duringInitialSetup)
        let responseCode = response.statusCode

        let decodedData = try? ZippyJSONDecoder().decode(ToolsOzoneCommunicationCreateTemplate.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
