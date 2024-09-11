import Foundation
internal import ZippyJSON

// lexicon: 1, id: tools.ozone.team.listMembers

public enum ToolsOzoneTeamListMembers {
    public static let typeIdentifier = "tools.ozone.team.listMembers"
    public struct Parameters: Parametrizable {
        public let limit: Int?
        public let cursor: String?

        public init(
            limit: Int? = nil,
            cursor: String? = nil
        ) {
            self.limit = limit
            self.cursor = cursor
        }
    }

    public struct Output: ATProtocolCodable {
        public let cursor: String?

        public let members: [ToolsOzoneTeamDefs.Member]

        // Standard public initializer
        public init(
            cursor: String? = nil,

            members: [ToolsOzoneTeamDefs.Member]
        ) {
            self.cursor = cursor

            self.members = members
        }
    }
}

public extension ATProtoClient.Tools.Ozone.Team {
    /// List all members with access to the ozone service.
    func listMembers(input: ToolsOzoneTeamListMembers.Parameters) async throws -> (responseCode: Int, data: ToolsOzoneTeamListMembers.Output?) {
        let endpoint = "/tools.ozone.team.listMembers"

        let queryItems = input.asQueryItems()
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: [:],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest, retryCount: 0, duringInitialSetup: false)
        let responseCode = response.statusCode

        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(ToolsOzoneTeamListMembers.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
