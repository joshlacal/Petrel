import Foundation

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

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            activated = try container.decode(Bool.self, forKey: .activated)

            validDid = try container.decode(Bool.self, forKey: .validDid)

            repoCommit = try container.decode(String.self, forKey: .repoCommit)

            repoRev = try container.decode(String.self, forKey: .repoRev)

            repoBlocks = try container.decode(Int.self, forKey: .repoBlocks)

            indexedRecords = try container.decode(Int.self, forKey: .indexedRecords)

            privateStateValues = try container.decode(Int.self, forKey: .privateStateValues)

            expectedBlobs = try container.decode(Int.self, forKey: .expectedBlobs)

            importedBlobs = try container.decode(Int.self, forKey: .importedBlobs)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(activated, forKey: .activated)

            try container.encode(validDid, forKey: .validDid)

            try container.encode(repoCommit, forKey: .repoCommit)

            try container.encode(repoRev, forKey: .repoRev)

            try container.encode(repoBlocks, forKey: .repoBlocks)

            try container.encode(indexedRecords, forKey: .indexedRecords)

            try container.encode(privateStateValues, forKey: .privateStateValues)

            try container.encode(expectedBlobs, forKey: .expectedBlobs)

            try container.encode(importedBlobs, forKey: .importedBlobs)
        }

        private enum CodingKeys: String, CodingKey {
            case activated
            case validDid
            case repoCommit
            case repoRev
            case repoBlocks
            case indexedRecords
            case privateStateValues
            case expectedBlobs
            case importedBlobs
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
