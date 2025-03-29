import Foundation

// lexicon: 1, id: com.atproto.repo.getRecord

public enum ComAtprotoRepoGetRecord {
    public static let typeIdentifier = "com.atproto.repo.getRecord"
    public struct Parameters: Parametrizable {
        public let repo: ATIdentifier
        public let collection: NSID
        public let rkey: RecordKey
        public let cid: CID?

        public init(
            repo: ATIdentifier,
            collection: NSID,
            rkey: RecordKey,
            cid: CID? = nil
        ) {
            self.repo = repo
            self.collection = collection
            self.rkey = rkey
            self.cid = cid
        }
    }

    public struct Output: ATProtocolCodable {
        public let uri: ATProtocolURI

        public let cid: CID?

        public let value: ATProtocolValueContainer

        // Standard public initializer
        public init(
            uri: ATProtocolURI,

            cid: CID? = nil,

            value: ATProtocolValueContainer

        ) {
            self.uri = uri

            self.cid = cid

            self.value = value
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            uri = try container.decode(ATProtocolURI.self, forKey: .uri)

            cid = try container.decodeIfPresent(CID.self, forKey: .cid)

            value = try container.decode(ATProtocolValueContainer.self, forKey: .value)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(uri, forKey: .uri)

            if let value = cid {
                try container.encode(value, forKey: .cid)
            }

            try container.encode(value, forKey: .value)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Add fields in lexicon-defined order

            let uriValue = try (uri as? DAGCBOREncodable)?.toCBORValue() ?? uri
            map = map.adding(key: "uri", value: uriValue)

            if let value = cid {
                let cidValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "cid", value: cidValue)
            }

            let valueValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
            map = map.adding(key: "value", value: valueValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case uri
            case cid
            case value
        }
    }

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case recordNotFound = "RecordNotFound."
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.Com.Atproto.Repo {
    /// Get a single record from a repository. Does not require auth.
    func getRecord(input: ComAtprotoRepoGetRecord.Parameters) async throws -> (responseCode: Int, data: ComAtprotoRepoGetRecord.Output?) {
        let endpoint = "com.atproto.repo.getRecord"

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
        let decodedData = try? decoder.decode(ComAtprotoRepoGetRecord.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
