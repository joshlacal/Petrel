import Foundation
import ZippyJSON

// lexicon: 1, id: com.atproto.identity.resolveHandle

public enum ComAtprotoIdentityResolveHandle {
    public static let typeIdentifier = "com.atproto.identity.resolveHandle"
    public struct Parameters: Parametrizable {
        public let handle: String

        public init(
            handle: String
        ) {
            self.handle = handle
        }
    }

    public struct Output: ATProtocolCodable {
        public let did: String

        // Standard public initializer
        public init(
            did: String

        ) {
            self.did = did
        }
    }
}

public extension ATProtoClient.Com.Atproto.Identity {
    /// Resolves a handle (domain name) to a DID.
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

        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(ComAtprotoIdentityResolveHandle.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
