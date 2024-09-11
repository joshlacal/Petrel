import Foundation
internal import ZippyJSON

// lexicon: 1, id: com.atproto.sync.getRecord

public enum ComAtprotoSyncGetRecord {
    public static let typeIdentifier = "com.atproto.sync.getRecord"
    public struct Parameters: Parametrizable {
        public let did: String
        public let collection: String
        public let rkey: String
        public let commit: String?

        public init(
            did: String,
            collection: String,
            rkey: String,
            commit: String? = nil
        ) {
            self.did = did
            self.collection = collection
            self.rkey = rkey
            self.commit = commit
        }
    }

    public struct Output: ATProtocolCodable {
        // Standard public initializer
        public init() {}
    }

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case recordNotFound = "RecordNotFound."
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
    /// Get data blocks needed to prove the existence or non-existence of record in the current version of repo. Does not require auth.
    func getRecord(input: ComAtprotoSyncGetRecord.Parameters) async throws -> (responseCode: Int, data: ComAtprotoSyncGetRecord.Output?) {
        let endpoint = "/com.atproto.sync.getRecord"

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
        let decodedData = try? decoder.decode(ComAtprotoSyncGetRecord.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
