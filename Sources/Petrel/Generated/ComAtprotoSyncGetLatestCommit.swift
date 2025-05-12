import Foundation

// lexicon: 1, id: com.atproto.sync.getLatestCommit

public enum ComAtprotoSyncGetLatestCommit {
    public static let typeIdentifier = "com.atproto.sync.getLatestCommit"
    public struct Parameters: Parametrizable {
        public let did: DID

        public init(
            did: DID
        ) {
            self.did = did
        }
    }

    public struct Output: ATProtocolCodable {
        public let cid: CID

        public let rev: TID

        // Standard public initializer
        public init(
            cid: CID,

            rev: TID

        ) {
            self.cid = cid

            self.rev = rev
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            cid = try container.decode(CID.self, forKey: .cid)

            rev = try container.decode(TID.self, forKey: .rev)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(cid, forKey: .cid)

            try container.encode(rev, forKey: .rev)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let cidValue = try cid.toCBORValue()
            map = map.adding(key: "cid", value: cidValue)

            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case cid
            case rev
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
    // MARK: - getLatestCommit

    /// Get the current commit CID & revision of the specified repo. Does not require auth.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getLatestCommit(input: ComAtprotoSyncGetLatestCommit.Parameters) async throws -> (responseCode: Int, data: ComAtprotoSyncGetLatestCommit.Output?) {
        let endpoint = "com.atproto.sync.getLatestCommit"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkService.performRequest(urlRequest)
        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(ComAtprotoSyncGetLatestCommit.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
