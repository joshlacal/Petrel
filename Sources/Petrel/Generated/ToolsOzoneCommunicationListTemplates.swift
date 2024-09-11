import Foundation
internal import ZippyJSON

// lexicon: 1, id: tools.ozone.communication.listTemplates

public enum ToolsOzoneCommunicationListTemplates {
    public static let typeIdentifier = "tools.ozone.communication.listTemplates"

    public struct Output: ATProtocolCodable {
        public let communicationTemplates: [ToolsOzoneCommunicationDefs.TemplateView]

        // Standard public initializer
        public init(
            communicationTemplates: [ToolsOzoneCommunicationDefs.TemplateView]
        ) {
            self.communicationTemplates = communicationTemplates
        }
    }
}

public extension ATProtoClient.Tools.Ozone.Communication {
    /// Get list of all communication templates.
    func listTemplates() async throws -> (responseCode: Int, data: ToolsOzoneCommunicationListTemplates.Output?) {
        let endpoint = "/tools.ozone.communication.listTemplates"

        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: [:],
            body: nil,
            queryItems: nil
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest, retryCount: 0, duringInitialSetup: false)
        let responseCode = response.statusCode

        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(ToolsOzoneCommunicationListTemplates.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
