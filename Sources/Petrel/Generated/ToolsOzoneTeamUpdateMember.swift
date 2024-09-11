import Foundation
internal import ZippyJSON

// lexicon: 1, id: tools.ozone.team.updateMember

public enum ToolsOzoneTeamUpdateMember {
    public static let typeIdentifier = "tools.ozone.team.updateMember"
    public struct Input: ATProtocolCodable {
        public let did: String
        public let disabled: Bool?
        public let role: String?

        // Standard public initializer
        public init(did: String, disabled: Bool? = nil, role: String? = nil) {
            self.did = did
            self.disabled = disabled
            self.role = role
        }
    }

    public typealias Output = ToolsOzoneTeamDefs.Member

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case memberNotFound = "MemberNotFound.The member being updated does not exist in the team"
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.Tools.Ozone.Team {
    /// Update a member in the ozone service. Requires admin role.
    func updateMember(
        input: ToolsOzoneTeamUpdateMember.Input,

        duringInitialSetup: Bool = false
    ) async throws -> (responseCode: Int, data: ToolsOzoneTeamUpdateMember.Output?) {
        let endpoint = "/tools.ozone.team.updateMember"

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

        let decodedData = try? ZippyJSONDecoder().decode(ToolsOzoneTeamUpdateMember.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
