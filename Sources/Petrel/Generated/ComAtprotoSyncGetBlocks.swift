import Foundation

// lexicon: 1, id: com.atproto.sync.getBlocks

public enum ComAtprotoSyncGetBlocks {
    public static let typeIdentifier = "com.atproto.sync.getBlocks"
    public struct Parameters: Parametrizable {
        public let did: DID
        public let cids: [CID]

        public init(
            did: DID,
            cids: [CID]
        ) {
            self.did = did
            self.cids = cids
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

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            let data = try container.decode(Data.self, forKey: .data)
            self.data = data
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(data, forKey: .data)
        }

        public func toCBORValue() throws -> Any {
            return data
        }

        private enum CodingKeys: String, CodingKey {
            case data
        }
    }

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case blockNotFound = "BlockNotFound."
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
    // MARK: - getBlocks

    /// Get data blocks from a given repo, by CID. For example, intermediate MST nodes, or records. Does not require auth; implemented by PDS.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getBlocks(input: ComAtprotoSyncGetBlocks.Parameters) async throws -> (responseCode: Int, data: ComAtprotoSyncGetBlocks.Output?) {
        let endpoint = "com.atproto.sync.getBlocks"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/vnd.ipld.car"],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkService.performRequest(urlRequest)

        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/vnd.ipld.car", actual: "nil")
        }

        if !contentType.lowercased().contains("application/vnd.ipld.car") {
            throw NetworkError.invalidContentType(expected: "application/vnd.ipld.car", actual: contentType)
        }

        let decodedData = ComAtprotoSyncGetBlocks.Output(data: responseData)

        return (responseCode, decodedData)
    }
}
