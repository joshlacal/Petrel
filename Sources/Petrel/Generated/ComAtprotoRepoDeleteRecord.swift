import Foundation
import ZippyJSON

// lexicon: 1, id: com.atproto.repo.deleteRecord

public enum ComAtprotoRepoDeleteRecord {
    public static let typeIdentifier = "com.atproto.repo.deleteRecord"
    public struct Input: ATProtocolCodable {
        public let repo: String
        public let collection: String
        public let rkey: String
        public let swapRecord: String?
        public let swapCommit: String?

        // Standard public initializer
        public init(repo: String, collection: String, rkey: String, swapRecord: String? = nil, swapCommit: String? = nil) {
            self.repo = repo
            self.collection = collection
            self.rkey = rkey
            self.swapRecord = swapRecord
            self.swapCommit = swapCommit
        }
    }

    public struct Output: ATProtocolCodable {
        public let commit: ComAtprotoRepoDefs.CommitMeta?

        // Standard public initializer
        public init(
            commit: ComAtprotoRepoDefs.CommitMeta? = nil

        ) {
            self.commit = commit
        }
    }

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case invalidSwap = "InvalidSwap."
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.Com.Atproto.Repo {
    /// Delete a repository record, or ensure it doesn't exist. Requires auth, implemented by PDS.
    func deleteRecord(
        input: ComAtprotoRepoDeleteRecord.Input

    ) async throws -> (responseCode: Int, data: ComAtprotoRepoDeleteRecord.Output?) {
        let endpoint = "com.atproto.repo.deleteRecord"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        headers["Accept"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
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
        let decodedData = try? decoder.decode(ComAtprotoRepoDeleteRecord.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
