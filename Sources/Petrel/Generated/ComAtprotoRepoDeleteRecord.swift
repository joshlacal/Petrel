import Foundation

// lexicon: 1, id: com.atproto.repo.deleteRecord

public enum ComAtprotoRepoDeleteRecord {
    public static let typeIdentifier = "com.atproto.repo.deleteRecord"
    public struct Input: ATProtocolCodable {
        public let repo: ATIdentifier
        public let collection: NSID
        public let rkey: RecordKey
        public let swapRecord: CID?
        public let swapCommit: CID?

        // Standard public initializer
        public init(repo: ATIdentifier, collection: NSID, rkey: RecordKey, swapRecord: CID? = nil, swapCommit: CID? = nil) {
            self.repo = repo
            self.collection = collection
            self.rkey = rkey
            self.swapRecord = swapRecord
            self.swapCommit = swapCommit
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            repo = try container.decode(ATIdentifier.self, forKey: .repo)

            collection = try container.decode(NSID.self, forKey: .collection)

            rkey = try container.decode(RecordKey.self, forKey: .rkey)

            swapRecord = try container.decodeIfPresent(CID.self, forKey: .swapRecord)

            swapCommit = try container.decodeIfPresent(CID.self, forKey: .swapCommit)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(repo, forKey: .repo)

            try container.encode(collection, forKey: .collection)

            try container.encode(rkey, forKey: .rkey)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(swapRecord, forKey: .swapRecord)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(swapCommit, forKey: .swapCommit)
        }

        private enum CodingKeys: String, CodingKey {
            case repo
            case collection
            case rkey
            case swapRecord
            case swapCommit
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let repoValue = try repo.toCBORValue()
            map = map.adding(key: "repo", value: repoValue)

            let collectionValue = try collection.toCBORValue()
            map = map.adding(key: "collection", value: collectionValue)

            let rkeyValue = try rkey.toCBORValue()
            map = map.adding(key: "rkey", value: rkeyValue)

            if let value = swapRecord {
                // Encode optional property even if it's an empty array for CBOR
                let swapRecordValue = try value.toCBORValue()
                map = map.adding(key: "swapRecord", value: swapRecordValue)
            }

            if let value = swapCommit {
                // Encode optional property even if it's an empty array for CBOR
                let swapCommitValue = try value.toCBORValue()
                map = map.adding(key: "swapCommit", value: swapCommitValue)
            }

            return map
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

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            commit = try container.decodeIfPresent(ComAtprotoRepoDefs.CommitMeta.self, forKey: .commit)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(commit, forKey: .commit)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            if let value = commit {
                // Encode optional property even if it's an empty array for CBOR
                let commitValue = try value.toCBORValue()
                map = map.adding(key: "commit", value: commitValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case commit
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
    // MARK: - deleteRecord

    /// Delete a repository record, or ensure it doesn't exist. Requires auth, implemented by PDS.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func deleteRecord(
        input: ComAtprotoRepoDeleteRecord.Input

    ) async throws -> (responseCode: Int, data: ComAtprotoRepoDeleteRecord.Output?) {
        let endpoint = "com.atproto.repo.deleteRecord"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        headers["Accept"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        let (responseData, response) = try await networkService.performRequest(urlRequest)

        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        // Only decode response data if request was successful
        if (200 ... 299).contains(responseCode) {
            do {
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(ComAtprotoRepoDeleteRecord.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for com.atproto.repo.deleteRecord: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
