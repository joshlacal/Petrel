import Foundation

// lexicon: 1, id: com.atproto.identity.resolveDid

public enum ComAtprotoIdentityResolveDid {
    public static let typeIdentifier = "com.atproto.identity.resolveDid"
    public struct Parameters: Parametrizable {
        public let did: DID

        public init(
            did: DID
        ) {
            self.did = did
        }
    }

    public struct Output: ATProtocolCodable {
        public let didDoc: DIDDocument

        // Standard public initializer
        public init(
            didDoc: DIDDocument

        ) {
            self.didDoc = didDoc
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            didDoc = try container.decode(DIDDocument.self, forKey: .didDoc)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(didDoc, forKey: .didDoc)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let didDocValue = try (didDoc as? DAGCBOREncodable)?.toCBORValue() ?? didDoc
            map = map.adding(key: "didDoc", value: didDocValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case didDoc
        }
    }

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case didNotFound = "DidNotFound.The DID resolution process confirmed that there is no current DID."
        case didDeactivated = "DidDeactivated.The DID previously existed, but has been deactivated."
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.Com.Atproto.Identity {
    /// Resolves DID to DID document. Does not bi-directionally verify handle.
    func resolveDid(input: ComAtprotoIdentityResolveDid.Parameters) async throws -> (responseCode: Int, data: ComAtprotoIdentityResolveDid.Output?) {
        let endpoint = "com.atproto.identity.resolveDid"

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
        let decodedData = try? decoder.decode(ComAtprotoIdentityResolveDid.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
