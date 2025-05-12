import Foundation

// lexicon: 1, id: com.atproto.sync.getHead

public enum ComAtprotoSyncGetHead {
    public static let typeIdentifier = "com.atproto.sync.getHead"
    public struct Parameters: Parametrizable {
        public let did: DID

        public init(
            did: DID
        ) {
            self.did = did
        }
    }

    public struct Output: ATProtocolCodable {
        public let root: CID

        // Standard public initializer
        public init(
            root: CID

        ) {
            self.root = root
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            root = try container.decode(CID.self, forKey: .root)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(root, forKey: .root)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let rootValue = try root.toCBORValue()
            map = map.adding(key: "root", value: rootValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case root
        }
    }

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case headNotFound = "HeadNotFound."
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.Com.Atproto.Sync {
    // MARK: - getHead

    /// DEPRECATED - please use com.atproto.sync.getLatestCommit instead
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getHead(input: ComAtprotoSyncGetHead.Parameters) async throws -> (responseCode: Int, data: ComAtprotoSyncGetHead.Output?) {
        let endpoint = "com.atproto.sync.getHead"

        let queryItems = input.asQueryItems()

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
        let decodedData = try? decoder.decode(ComAtprotoSyncGetHead.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
