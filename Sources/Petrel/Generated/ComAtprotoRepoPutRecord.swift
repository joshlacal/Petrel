import Foundation
internal import ZippyJSON

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
        input: ComAtprotoRepoPutRecord.Input,

        duringInitialSetup: Bool = false
    ) async throws -> (responseCode: Int, data: ComAtprotoRepoPutRecord.Output?) {
        let endpoint = "/com.atproto.repo.putRecord"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: ["Content-Type": "application/json"],
            body: requestData,
            queryItems: nil
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest, retryCount: 0, duringInitialSetup: duringInitialSetup)
        let responseCode = response.statusCode

        let decodedData = try? ZippyJSONDecoder().decode(ComAtprotoRepoPutRecord.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
