import Foundation
import ZippyJSON

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
        public let data: Data

        // Standard public initializer
        public init(
            data: Data

        ) {
            self.data = data
        }
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
        let endpoint = "com.atproto.sync.getRecord"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/vnd.ipld.car"],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest)
        let responseCode = response.statusCode

        // Content-Type validation
        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/vnd.ipld.car", actual: "nil")
        }

        if !contentType.lowercased().contains("application/vnd.ipld.car") {
            throw NetworkError.invalidContentType(expected: "application/vnd.ipld.car", actual: contentType)
        }

        // Data decoding and validation

        let decodedData = ComAtprotoSyncGetRecord.Output(data: responseData)

        return (responseCode, decodedData)
    }
}
