import Foundation
internal import ZippyJSON

// lexicon: 1, id: com.atproto.sync.getBlob

public enum ComAtprotoSyncGetBlob {
    public static let typeIdentifier = "com.atproto.sync.getBlob"
    public struct Parameters: Parametrizable {
        public let did: String
        public let cid: String

        public init(
            did: String,
            cid: String
        ) {
            self.did = did
            self.cid = cid
        }
    }

    public struct Output: ATProtocolCodable {
        public let data: Data

        // Standard public initializer
        public init(
            data: Data
        ) {
            self.data = data
        }
    }

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case blobNotFound = "BlobNotFound."
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
    /// Get a blob associated with a given account. Returns the full blob as originally uploaded. Does not require auth; implemented by PDS.
    func getBlob(input: ComAtprotoSyncGetBlob.Parameters) async throws -> (responseCode: Int, data: ComAtprotoSyncGetBlob.Output?) {
        let endpoint = "/com.atproto.sync.getBlob"

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
        let decodedData = try? decoder.decode(ComAtprotoSyncGetBlob.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
