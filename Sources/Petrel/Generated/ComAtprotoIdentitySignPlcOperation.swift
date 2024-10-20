import Foundation
import ZippyJSON

// lexicon: 1, id: com.atproto.identity.signPlcOperation

public enum ComAtprotoIdentitySignPlcOperation {
    public static let typeIdentifier = "com.atproto.identity.signPlcOperation"
    public struct Input: ATProtocolCodable {
        public let token: String?
        public let rotationKeys: [String]?
        public let alsoKnownAs: [String]?
        public let verificationMethods: ATProtocolValueContainer?
        public let services: ATProtocolValueContainer?

        // Standard public initializer
        public init(token: String? = nil, rotationKeys: [String]? = nil, alsoKnownAs: [String]? = nil, verificationMethods: ATProtocolValueContainer? = nil, services: ATProtocolValueContainer? = nil) {
            self.token = token
            self.rotationKeys = rotationKeys
            self.alsoKnownAs = alsoKnownAs
            self.verificationMethods = verificationMethods
            self.services = services
        }
    }

    public struct Output: ATProtocolCodable {
        public let operation: ATProtocolValueContainer

        // Standard public initializer
        public init(
            operation: ATProtocolValueContainer

        ) {
            self.operation = operation
        }
    }
}

public extension ATProtoClient.Com.Atproto.Identity {
    /// Signs a PLC operation to update some value(s) in the requesting DID's document.
    func signPlcOperation(
        input: ComAtprotoIdentitySignPlcOperation.Input

    ) async throws -> (responseCode: Int, data: ComAtprotoIdentitySignPlcOperation.Output?) {
        let endpoint = "com.atproto.identity.signPlcOperation"

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

        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(ComAtprotoIdentitySignPlcOperation.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
