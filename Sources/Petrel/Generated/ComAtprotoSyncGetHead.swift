import Foundation

// lexicon: 1, id: com.atproto.sync.getHead

public enum ComAtprotoSyncGetHead {
    public static let typeIdentifier = "com.atproto.sync.getHead"
    public struct Parameters: Parametrizable {
        public let did: String

        public init(
            did: String
        ) {
            self.did = did
        }
    }

    public struct Output: ATProtocolCodable {
        public let root: String

        // Standard public initializer
        public init(
            root: String

        ) {
            self.root = root
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            root = try container.decode(String.self, forKey: .root)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(root, forKey: .root)
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
    /// DEPRECATED - please use com.atproto.sync.getLatestCommit instead
    func getHead(input: ComAtprotoSyncGetHead.Parameters) async throws -> (responseCode: Int, data: ComAtprotoSyncGetHead.Output?) {
        let endpoint = "com.atproto.sync.getHead"

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
        let decodedData = try? decoder.decode(ComAtprotoSyncGetHead.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
