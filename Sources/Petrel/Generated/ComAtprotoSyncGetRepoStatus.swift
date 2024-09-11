import Foundation
internal import ZippyJSON

// lexicon: 1, id: com.atproto.sync.getRepoStatus

public enum ComAtprotoSyncGetRepoStatus {
    public static let typeIdentifier = "com.atproto.sync.getRepoStatus"
    public struct Parameters: Parametrizable {
        public let did: String

        public init(
            did: String
        ) {
            self.did = did
        }
    }

    public struct Output: ATProtocolCodable {
        public let did: String

        public let active: Bool

        public let status: String?

        public let rev: String?

        // Standard public initializer
        public init(
            did: String,

            active: Bool,

            status: String? = nil,

            rev: String? = nil
        ) {
            self.did = did

            self.active = active

            self.status = status

            self.rev = rev
        }
    }

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case repoNotFound = "RepoNotFound."
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.Com.Atproto.Sync {
    /// Get the hosting status for a repository, on this server. Expected to be implemented by PDS and Relay.
    func getRepoStatus(input: ComAtprotoSyncGetRepoStatus.Parameters) async throws -> (responseCode: Int, data: ComAtprotoSyncGetRepoStatus.Output?) {
        let endpoint = "/com.atproto.sync.getRepoStatus"

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
        let decodedData = try? decoder.decode(ComAtprotoSyncGetRepoStatus.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
