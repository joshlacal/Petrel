import Foundation

// lexicon: 1, id: com.atproto.repo.putRecord

public enum ComAtprotoRepoPutRecord {
    public static let typeIdentifier = "com.atproto.repo.putRecord"
    public struct Input: ATProtocolCodable {
        public let repo: String
        public let collection: String
        public let rkey: String
        public let validate: Bool?
        public let record: ATProtocolValueContainer
        public let swapRecord: String?
        public let swapCommit: String?

        // Standard public initializer
        public init(repo: String, collection: String, rkey: String, validate: Bool? = nil, record: ATProtocolValueContainer, swapRecord: String? = nil, swapCommit: String? = nil) {
            self.repo = repo
            self.collection = collection
            self.rkey = rkey
            self.validate = validate
            self.record = record
            self.swapRecord = swapRecord
            self.swapCommit = swapCommit
        }
    }

    public struct Output: ATProtocolCodable {
        public let uri: ATProtocolURI

        public let cid: String

        public let commit: ComAtprotoRepoDefs.CommitMeta?

        public let validationStatus: String?

        // Standard public initializer
        public init(
            uri: ATProtocolURI,

            cid: String,

            commit: ComAtprotoRepoDefs.CommitMeta? = nil,

            validationStatus: String? = nil

        ) {
            self.uri = uri

            self.cid = cid

            self.commit = commit

            self.validationStatus = validationStatus
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
    /// Write a repository record, creating or updating it as needed. Requires auth, implemented by PDS.
    func putRecord(
        input: ComAtprotoRepoPutRecord.Input

    ) async throws -> (responseCode: Int, data: ComAtprotoRepoPutRecord.Output?) {
        let endpoint = "com.atproto.repo.putRecord"

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
        let decodedData = try? decoder.decode(ComAtprotoRepoPutRecord.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
