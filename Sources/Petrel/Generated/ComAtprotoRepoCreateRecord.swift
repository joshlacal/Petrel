import Foundation

// lexicon: 1, id: com.atproto.repo.createRecord

public enum ComAtprotoRepoCreateRecord {
    public static let typeIdentifier = "com.atproto.repo.createRecord"
    public struct Input: ATProtocolCodable {
        public let repo: ATIdentifier
        public let collection: NSID
        public let rkey: RecordKey?
        public let validate: Bool?
        public let record: ATProtocolValueContainer
        public let swapCommit: CID?

        // Standard public initializer
        public init(repo: ATIdentifier, collection: NSID, rkey: RecordKey? = nil, validate: Bool? = nil, record: ATProtocolValueContainer, swapCommit: CID? = nil) {
            self.repo = repo
            self.collection = collection
            self.rkey = rkey
            self.validate = validate
            self.record = record
            self.swapCommit = swapCommit
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            repo = try container.decode(ATIdentifier.self, forKey: .repo)

            collection = try container.decode(NSID.self, forKey: .collection)

            rkey = try container.decodeIfPresent(RecordKey.self, forKey: .rkey)

            validate = try container.decodeIfPresent(Bool.self, forKey: .validate)

            record = try container.decode(ATProtocolValueContainer.self, forKey: .record)

            swapCommit = try container.decodeIfPresent(CID.self, forKey: .swapCommit)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(repo, forKey: .repo)

            try container.encode(collection, forKey: .collection)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(rkey, forKey: .rkey)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(validate, forKey: .validate)

            try container.encode(record, forKey: .record)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(swapCommit, forKey: .swapCommit)
        }

        private enum CodingKeys: String, CodingKey {
            case repo
            case collection
            case rkey
            case validate
            case record
            case swapCommit
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let repoValue = try (repo as? DAGCBOREncodable)?.toCBORValue() ?? repo
            map = map.adding(key: "repo", value: repoValue)

            let collectionValue = try (collection as? DAGCBOREncodable)?.toCBORValue() ?? collection
            map = map.adding(key: "collection", value: collectionValue)

            if let value = rkey {
                // Encode optional property even if it's an empty array for CBOR

                let rkeyValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "rkey", value: rkeyValue)
            }

            if let value = validate {
                // Encode optional property even if it's an empty array for CBOR

                let validateValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "validate", value: validateValue)
            }

            let recordValue = try (record as? DAGCBOREncodable)?.toCBORValue() ?? record
            map = map.adding(key: "record", value: recordValue)

            if let value = swapCommit {
                // Encode optional property even if it's an empty array for CBOR

                let swapCommitValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "swapCommit", value: swapCommitValue)
            }

            return map
        }
    }

    public struct Output: ATProtocolCodable {
        public let uri: ATProtocolURI

        public let cid: CID

        public let commit: ComAtprotoRepoDefs.CommitMeta?

        public let validationStatus: String?

        // Standard public initializer
        public init(
            uri: ATProtocolURI,

            cid: CID,

            commit: ComAtprotoRepoDefs.CommitMeta? = nil,

            validationStatus: String? = nil

        ) {
            self.uri = uri

            self.cid = cid

            self.commit = commit

            self.validationStatus = validationStatus
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            uri = try container.decode(ATProtocolURI.self, forKey: .uri)

            cid = try container.decode(CID.self, forKey: .cid)

            commit = try container.decodeIfPresent(ComAtprotoRepoDefs.CommitMeta.self, forKey: .commit)

            validationStatus = try container.decodeIfPresent(String.self, forKey: .validationStatus)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(uri, forKey: .uri)

            try container.encode(cid, forKey: .cid)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(commit, forKey: .commit)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(validationStatus, forKey: .validationStatus)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let uriValue = try (uri as? DAGCBOREncodable)?.toCBORValue() ?? uri
            map = map.adding(key: "uri", value: uriValue)

            let cidValue = try (cid as? DAGCBOREncodable)?.toCBORValue() ?? cid
            map = map.adding(key: "cid", value: cidValue)

            if let value = commit {
                // Encode optional property even if it's an empty array for CBOR

                let commitValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "commit", value: commitValue)
            }

            if let value = validationStatus {
                // Encode optional property even if it's an empty array for CBOR

                let validationStatusValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "validationStatus", value: validationStatusValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case uri
            case cid
            case commit
            case validationStatus
        }
    }

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case invalidSwap = "InvalidSwap.Indicates that 'swapCommit' didn't match current repo commit."
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.Com.Atproto.Repo {
    /// Create a single new repository record. Requires auth, implemented by PDS.
    func createRecord(
        input: ComAtprotoRepoCreateRecord.Input

    ) async throws -> (responseCode: Int, data: ComAtprotoRepoCreateRecord.Output?) {
        let endpoint = "com.atproto.repo.createRecord"

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
        let decodedData = try? decoder.decode(ComAtprotoRepoCreateRecord.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
