import Foundation
internal import ZippyJSON

// lexicon: 1, id: com.atproto.sync.getLatestCommit

public enum ComAtprotoSyncGetLatestCommit {
    public static let typeIdentifier = "com.atproto.sync.getLatestCommit"
    public struct Parameters: Parametrizable {
        public let did: String

        public init(
            did: String
        ) {
            self.did = did
        }
    }

    public struct Output: ATProtocolCodable {
        public let cid: String

        public let rev: String

        // Standard public initializer
        public init(
            cid: String,

            rev: String
        ) {
            self.cid = cid

            self.rev = rev
        }
    }

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case repoNotFound = "RepoNotFound."
        case repoTakendown = "RepoTakendown."
        case repoSuspended = "RepoSuspended."
        case repoDeactivated = "RepoDeactivated."
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.Com.Atproto.Sync {
    /// Get the current commit CID & revision of the specified repo. Does not require auth.
    func getLatestCommit(input: ComAtprotoSyncGetLatestCommit.Parameters) async throws -> (responseCode: Int, data: ComAtprotoSyncGetLatestCommit.Output?) {
        let endpoint = "/com.atproto.sync.getLatestCommit"

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
        let decodedData = try? decoder.decode(ComAtprotoSyncGetLatestCommit.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
