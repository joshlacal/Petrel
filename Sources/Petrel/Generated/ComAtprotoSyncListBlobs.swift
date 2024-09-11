import Foundation
internal import ZippyJSON

// lexicon: 1, id: com.atproto.sync.listBlobs

public enum ComAtprotoSyncListBlobs {
    public static let typeIdentifier = "com.atproto.sync.listBlobs"
    public struct Parameters: Parametrizable {
        public let did: String
        public let since: String?
        public let limit: Int?
        public let cursor: String?

        public init(
            did: String,
            since: String? = nil,
            limit: Int? = nil,
            cursor: String? = nil
        ) {
            self.did = did
            self.since = since
            self.limit = limit
            self.cursor = cursor
        }
    }

    public struct Output: ATProtocolCodable {
        public let cursor: String?

        public let cids: [String]

        // Standard public initializer
        public init(
            cursor: String? = nil,

            cids: [String]
        ) {
            self.cursor = cursor

            self.cids = cids
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
    /// List blob CIDs for an account, since some repo revision. Does not require auth; implemented by PDS.
    func listBlobs(input: ComAtprotoSyncListBlobs.Parameters) async throws -> (responseCode: Int, data: ComAtprotoSyncListBlobs.Output?) {
        let endpoint = "/com.atproto.sync.listBlobs"

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
        let decodedData = try? decoder.decode(ComAtprotoSyncListBlobs.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
