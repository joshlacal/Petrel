import Foundation

// lexicon: 1, id: com.atproto.sync.getRepo

public enum ComAtprotoSyncGetRepo {
    public static let typeIdentifier = "com.atproto.sync.getRepo"
    public struct Parameters: Parametrizable {
        public let did: String
        public let since: String?

        public init(
            did: String,
            since: String? = nil
        ) {
            self.did = did
            self.since = since
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
    /// Download a repository export as CAR file. Optionally only a 'diff' since a previous revision. Does not require auth; implemented by PDS.
    func getRepo(input: ComAtprotoSyncGetRepo.Parameters) async throws -> (responseCode: Int, data: ComAtprotoSyncGetRepo.Output?) {
        let endpoint = "com.atproto.sync.getRepo"

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

        let decodedData = ComAtprotoSyncGetRepo.Output(data: responseData)

        return (responseCode, decodedData)
    }
}
