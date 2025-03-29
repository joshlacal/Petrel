import Foundation

// lexicon: 1, id: com.atproto.identity.resolveHandle

public enum ComAtprotoIdentityResolveHandle {
    public static let typeIdentifier = "com.atproto.identity.resolveHandle"
    public struct Parameters: Parametrizable {
        public let handle: Handle

        public init(
            handle: Handle
        ) {
            self.handle = handle
        }
    }

    public struct Output: ATProtocolCodable {
        public let did: DID

        // Standard public initializer
        public init(
            did: DID

        ) {
            self.did = did
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            did = try container.decode(DID.self, forKey: .did)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(did, forKey: .did)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Add fields in lexicon-defined order

            let didValue = try (did as? DAGCBOREncodable)?.toCBORValue() ?? did
            map = map.adding(key: "did", value: didValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case did
        }
    }

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case handleNotFound = "HandleNotFound.The resolution process confirmed that the handle does not resolve to any DID."
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.Com.Atproto.Identity {
    /// Resolves an atproto handle (hostname) to a DID. Does not necessarily bi-directionally verify against the the DID document.
    func resolveHandle(input: ComAtprotoIdentityResolveHandle.Parameters) async throws -> (responseCode: Int, data: ComAtprotoIdentityResolveHandle.Output?) {
        let endpoint = "com.atproto.identity.resolveHandle"

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
        let decodedData = try? decoder.decode(ComAtprotoIdentityResolveHandle.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
