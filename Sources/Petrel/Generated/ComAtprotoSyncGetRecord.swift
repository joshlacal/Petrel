import Foundation

// lexicon: 1, id: com.atproto.sync.getRecord

public enum ComAtprotoSyncGetRecord {
    public static let typeIdentifier = "com.atproto.sync.getRecord"
    public struct Parameters: Parametrizable {
        public let did: DID
        public let collection: NSID
        public let rkey: RecordKey

        public init(
            did: DID,
            collection: NSID,
            rkey: RecordKey
        ) {
            self.did = did
            self.collection = collection
            self.rkey = rkey
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
    // MARK: - getRecord

    /// Get data blocks needed to prove the existence or non-existence of record in the current version of repo. Does not require auth.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getRecord(input: ComAtprotoSyncGetRecord.Parameters) async throws -> (responseCode: Int, data: ComAtprotoSyncGetRecord.Output?) {
        let endpoint = "com.atproto.sync.getRecord"

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

        let decodedData = ComAtprotoSyncGetRecord.Output(data: responseData)

        return (responseCode, decodedData)
    }
}
