import Foundation

// lexicon: 1, id: tools.ozone.moderation.getEvent

public enum ToolsOzoneModerationGetEvent {
    public static let typeIdentifier = "tools.ozone.moderation.getEvent"
    public struct Parameters: Parametrizable {
        public let id: Int

        public init(
            id: Int
        ) {
            self.id = id
        }
    }

    public typealias Output = ToolsOzoneModerationDefs.ModEventViewDetail
}

public extension ATProtoClient.Tools.Ozone.Moderation {
    /// Get details about a moderation event.
    func getEvent(input: ToolsOzoneModerationGetEvent.Parameters) async throws -> (responseCode: Int, data: ToolsOzoneModerationGetEvent.Output?) {
        let endpoint = "tools.ozone.moderation.getEvent"

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

        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(ToolsOzoneModerationGetEvent.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
