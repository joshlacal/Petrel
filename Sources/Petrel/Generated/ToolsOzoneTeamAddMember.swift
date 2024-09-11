import Foundation
internal import ZippyJSON

// lexicon: 1, id: tools.ozone.team.addMember

public enum ToolsOzoneTeamAddMember {
    public static let typeIdentifier = "tools.ozone.team.addMember"
    public struct Input: ATProtocolCodable {
        public let did: String
        public let role: String

        // Standard public initializer
        public init(did: String, role: String) {
            self.did = did
            self.role = role
        }
    }

    public typealias Output = ToolsOzoneTeamDefs.Member

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case memberAlreadyExists = "MemberAlreadyExists.Member already exists in the team."
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.Tools.Ozone.Team {
    /// Add a member to the ozone team. Requires admin role.
    func addMember(
        input: ToolsOzoneTeamAddMember.Input,

        duringInitialSetup: Bool = false
    ) async throws -> (responseCode: Int, data: ToolsOzoneTeamAddMember.Output?) {
        let endpoint = "/tools.ozone.team.addMember"

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

        let decodedData = try? ZippyJSONDecoder().decode(ToolsOzoneTeamAddMember.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
