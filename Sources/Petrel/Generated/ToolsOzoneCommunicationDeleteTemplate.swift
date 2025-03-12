import Foundation

// lexicon: 1, id: tools.ozone.communication.deleteTemplate

public enum ToolsOzoneCommunicationDeleteTemplate {
    public static let typeIdentifier = "tools.ozone.communication.deleteTemplate"
    public struct Input: ATProtocolCodable {
        public let id: String

        // Standard public initializer
        public init(id: String) {
            self.id = id
        }
    }
}

public extension ATProtoClient.Tools.Ozone.Communication {
    /// Delete a communication template.
    func deleteTemplate(
        input: ToolsOzoneCommunicationDeleteTemplate.Input

    ) async throws -> Int {
        let endpoint = "tools.ozone.communication.deleteTemplate"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        let (_, response) = try await networkManager.performRequest(urlRequest)
        let responseCode = response.statusCode
        return responseCode
    }
}
