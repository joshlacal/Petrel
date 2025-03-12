import Foundation
import ZippyJSON

// lexicon: 1, id: com.atproto.server.checkAccountStatus

public enum ComAtprotoServerCheckAccountStatus {
    public static let typeIdentifier = "com.atproto.server.checkAccountStatus"

    public struct Output: ATProtocolCodable {
        public let activated: Bool

        public let validDid: Bool

        public let repoCommit: String

        public let repoRev: String

        public let repoBlocks: Int

        public let indexedRecords: Int

        public let privateStateValues: Int

        public let expectedBlobs: Int

        public let importedBlobs: Int

        // Standard public initializer
        public init(
            activated: Bool,

            validDid: Bool,

            repoCommit: String,

            repoRev: String,

            repoBlocks: Int,

            indexedRecords: Int,

            privateStateValues: Int,

            expectedBlobs: Int,

            importedBlobs: Int

        ) {
            self.activated = activated

            self.validDid = validDid

            self.repoCommit = repoCommit

            self.repoRev = repoRev

            self.repoBlocks = repoBlocks

            self.indexedRecords = indexedRecords

            self.privateStateValues = privateStateValues

            self.expectedBlobs = expectedBlobs

            self.importedBlobs = importedBlobs
        }
    }
}

public extension ATProtoClient.Com.Atproto.Server {
    /// Returns the status of an account, especially as pertaining to import or recovery. Can be called many times over the course of an account migration. Requires auth and can only be called pertaining to oneself.
    func checkAccountStatus() async throws -> (responseCode: Int, data: ComAtprotoServerCheckAccountStatus.Output?) {
        let endpoint = "com.atproto.server.checkAccountStatus"

        let queryItems: [URLQueryItem]? = nil

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
        let decodedData = try? decoder.decode(ComAtprotoServerCheckAccountStatus.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
