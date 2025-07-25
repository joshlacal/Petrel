import Foundation

// lexicon: 1, id: com.atproto.server.checkAccountStatus

public enum ComAtprotoServerCheckAccountStatus {
    public static let typeIdentifier = "com.atproto.server.checkAccountStatus"

    public struct Output: ATProtocolCodable {
        public let activated: Bool

        public let validDid: Bool

        public let repoCommit: CID

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

            repoCommit: CID,

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

            repoCommit = try container.decode(CID.self, forKey: .repoCommit)

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

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let activatedValue = try activated.toCBORValue()
            map = map.adding(key: "activated", value: activatedValue)

            let validDidValue = try validDid.toCBORValue()
            map = map.adding(key: "validDid", value: validDidValue)

            let repoCommitValue = try repoCommit.toCBORValue()
            map = map.adding(key: "repoCommit", value: repoCommitValue)

            let repoRevValue = try repoRev.toCBORValue()
            map = map.adding(key: "repoRev", value: repoRevValue)

            let repoBlocksValue = try repoBlocks.toCBORValue()
            map = map.adding(key: "repoBlocks", value: repoBlocksValue)

            let indexedRecordsValue = try indexedRecords.toCBORValue()
            map = map.adding(key: "indexedRecords", value: indexedRecordsValue)

            let privateStateValuesValue = try privateStateValues.toCBORValue()
            map = map.adding(key: "privateStateValues", value: privateStateValuesValue)

            let expectedBlobsValue = try expectedBlobs.toCBORValue()
            map = map.adding(key: "expectedBlobs", value: expectedBlobsValue)

            let importedBlobsValue = try importedBlobs.toCBORValue()
            map = map.adding(key: "importedBlobs", value: importedBlobsValue)

            return map
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
    // MARK: - checkAccountStatus

    /// Returns the status of an account, especially as pertaining to import or recovery. Can be called many times over the course of an account migration. Requires auth and can only be called pertaining to oneself.
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func checkAccountStatus() async throws -> (responseCode: Int, data: ComAtprotoServerCheckAccountStatus.Output?) {
        let endpoint = "com.atproto.server.checkAccountStatus"

        let queryItems: [URLQueryItem]? = nil

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
        let decodedData = try? decoder.decode(ComAtprotoServerCheckAccountStatus.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
