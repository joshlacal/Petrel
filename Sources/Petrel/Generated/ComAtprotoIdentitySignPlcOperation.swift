import Foundation
internal import ZippyJSON

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
        input: ComAtprotoIdentitySignPlcOperation.Input,

        duringInitialSetup: Bool = false
    ) async throws -> (responseCode: Int, data: ComAtprotoIdentitySignPlcOperation.Output?) {
        let endpoint = "/com.atproto.identity.signPlcOperation"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: ["Content-Type": "application/json"],
            body: requestData,
            queryItems: nil
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest, retryCount: 0, duringInitialSetup: duringInitialSetup)
        let responseCode = response.statusCode

        let decodedData = try? ZippyJSONDecoder().decode(ComAtprotoIdentitySignPlcOperation.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
