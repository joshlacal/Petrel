import Foundation

// lexicon: 1, id: com.atproto.repo.describeRepo

public enum ComAtprotoRepoDescribeRepo {
    public static let typeIdentifier = "com.atproto.repo.describeRepo"
    public struct Parameters: Parametrizable {
        public let repo: ATIdentifier

        public init(
            repo: ATIdentifier
        ) {
            self.repo = repo
        }
    }

    public struct Output: ATProtocolCodable {
        public let handle: Handle

        public let did: DID

        public let didDoc: DIDDocument

        public let collections: [NSID]

        public let handleIsCorrect: Bool

        // Standard public initializer
        public init(
            handle: Handle,

            did: DID,

            didDoc: DIDDocument,

            collections: [NSID],

            handleIsCorrect: Bool

        ) {
            self.handle = handle

            self.did = did

            self.didDoc = didDoc

            self.collections = collections

            self.handleIsCorrect = handleIsCorrect
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            handle = try container.decode(Handle.self, forKey: .handle)

            did = try container.decode(DID.self, forKey: .did)

            didDoc = try container.decode(DIDDocument.self, forKey: .didDoc)

            collections = try container.decode([NSID].self, forKey: .collections)

            handleIsCorrect = try container.decode(Bool.self, forKey: .handleIsCorrect)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(handle, forKey: .handle)

            try container.encode(did, forKey: .did)

            try container.encode(didDoc, forKey: .didDoc)

            try container.encode(collections, forKey: .collections)

            try container.encode(handleIsCorrect, forKey: .handleIsCorrect)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Add fields in lexicon-defined order

            let handleValue = try (handle as? DAGCBOREncodable)?.toCBORValue() ?? handle
            map = map.adding(key: "handle", value: handleValue)

            let didValue = try (did as? DAGCBOREncodable)?.toCBORValue() ?? did
            map = map.adding(key: "did", value: didValue)

            let didDocValue = try (didDoc as? DAGCBOREncodable)?.toCBORValue() ?? didDoc
            map = map.adding(key: "didDoc", value: didDocValue)

            let collectionsValue = try (collections as? DAGCBOREncodable)?.toCBORValue() ?? collections
            map = map.adding(key: "collections", value: collectionsValue)

            let handleIsCorrectValue = try (handleIsCorrect as? DAGCBOREncodable)?.toCBORValue() ?? handleIsCorrect
            map = map.adding(key: "handleIsCorrect", value: handleIsCorrectValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case handle
            case did
            case didDoc
            case collections
            case handleIsCorrect
        }
    }
}

public extension ATProtoClient.Com.Atproto.Repo {
    /// Get information about an account and repository, including the list of collections. Does not require auth.
    func describeRepo(input: ComAtprotoRepoDescribeRepo.Parameters) async throws -> (responseCode: Int, data: ComAtprotoRepoDescribeRepo.Output?) {
        let endpoint = "com.atproto.repo.describeRepo"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest)
        let responseCode = response.statusCode

        // Content-Type validation
        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        // Data decoding and validation

        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(ComAtprotoRepoDescribeRepo.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
