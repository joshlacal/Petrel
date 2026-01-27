import Foundation

// lexicon: 1, id: com.atproto.identity.submitPlcOperation

public enum ComAtprotoIdentitySubmitPlcOperation {
    public static let typeIdentifier = "com.atproto.identity.submitPlcOperation"
    public struct Input: ATProtocolCodable {
        public let operation: ATProtocolValueContainer

        /// Standard public initializer
        public init(operation: ATProtocolValueContainer) {
            self.operation = operation
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            operation = try container.decode(ATProtocolValueContainer.self, forKey: .operation)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(operation, forKey: .operation)
        }

        private enum CodingKeys: String, CodingKey {
            case operation
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let operationValue = try operation.toCBORValue()
            map = map.adding(key: "operation", value: operationValue)

            return map
        }
    }
}

public extension ATProtoClient.Com.Atproto.Identity {
    // MARK: - submitPlcOperation

    /// Validates a PLC operation to ensure that it doesn't violate a service's constraints or get the identity into a bad state, then submits it to the PLC registry
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: The HTTP response code
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func submitPlcOperation(
        input: ComAtprotoIdentitySubmitPlcOperation.Input

    ) async throws -> Int {
        let endpoint = "com.atproto.identity.submitPlcOperation"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "com.atproto.identity.submitPlcOperation")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (_, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        return response.statusCode
    }
}
