import Foundation
internal import ZippyJSON

// lexicon: 1, id: com.atproto.identity.submitPlcOperation

public enum ComAtprotoIdentitySubmitPlcOperation {
    public static let typeIdentifier = "com.atproto.identity.submitPlcOperation"
    public struct Input: ATProtocolCodable {
        public let operation: ATProtocolValueContainer

        // Standard public initializer
        public init(operation: ATProtocolValueContainer) {
            self.operation = operation
        }
    }
}

public extension ATProtoClient.Com.Atproto.Identity {
    /// Validates a PLC operation to ensure that it doesn't violate a service's constraints or get the identity into a bad state, then submits it to the PLC registry
    func submitPlcOperation(
        input: ComAtprotoIdentitySubmitPlcOperation.Input,

        duringInitialSetup: Bool = false
    ) async throws -> Int {
        let endpoint = "/com.atproto.identity.submitPlcOperation"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: ["Content-Type": "application/json"],
            body: requestData,
            queryItems: nil
        )

        let (_, response) = try await networkManager.performRequest(urlRequest, retryCount: 0, duringInitialSetup: duringInitialSetup)
        let responseCode = response.statusCode

        return responseCode
    }
}
