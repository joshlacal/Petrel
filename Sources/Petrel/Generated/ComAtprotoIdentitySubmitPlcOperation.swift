import Foundation
import ZippyJSON

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
        input: ComAtprotoIdentitySubmitPlcOperation.Input

    ) async throws -> Int {
        let endpoint = "com.atproto.identity.submitPlcOperation"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        let (_, response) = try await networkManager.performRequest(urlRequest)
        let responseCode = response.statusCode
        return responseCode
    }
}
