import Foundation
import ZippyJSON

// lexicon: 1, id: com.atproto.repo.describeRepo

public enum ComAtprotoRepoDescribeRepo {
    public static let typeIdentifier = "com.atproto.repo.describeRepo"
    public struct Parameters: Parametrizable {
        public let repo: String

        public init(
            repo: String
        ) {
            self.repo = repo
        }
    }

    public struct Output: ATProtocolCodable {
        public let handle: String

        public let did: String

        public let didDoc: DIDDocument

        public let collections: [String]

        public let handleIsCorrect: Bool

        // Standard public initializer
        public init(
            handle: String,

            did: String,

            didDoc: DIDDocument,

            collections: [String],

            handleIsCorrect: Bool

        ) {
            self.handle = handle

            self.did = did

            self.didDoc = didDoc

            self.collections = collections

            self.handleIsCorrect = handleIsCorrect
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
