import Foundation
internal import ZippyJSON

// lexicon: 1, id: tools.ozone.moderation.getRepo

public enum ToolsOzoneModerationGetRepo {
    public static let typeIdentifier = "tools.ozone.moderation.getRepo"
    public struct Parameters: Parametrizable {
        public let did: String

        public init(
            did: String
        ) {
            self.did = did
        }
    }

    public typealias Output = ToolsOzoneModerationDefs.RepoViewDetail

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case repoNotFound = "RepoNotFound."
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.Tools.Ozone.Moderation {
    /// Get details about a repository.
    func getRepo(input: ToolsOzoneModerationGetRepo.Parameters) async throws -> (responseCode: Int, data: ToolsOzoneModerationGetRepo.Output?) {
        let endpoint = "/tools.ozone.moderation.getRepo"

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
        let decodedData = try? decoder.decode(ToolsOzoneModerationGetRepo.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
