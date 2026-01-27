import Foundation

// lexicon: 1, id: com.atproto.admin.updateAccountHandle

public enum ComAtprotoAdminUpdateAccountHandle {
    public static let typeIdentifier = "com.atproto.admin.updateAccountHandle"
    public struct Input: ATProtocolCodable {
        public let did: DID
        public let handle: Handle

        /// Standard public initializer
        public init(did: DID, handle: Handle) {
            self.did = did
            self.handle = handle
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            did = try container.decode(DID.self, forKey: .did)
            handle = try container.decode(Handle.self, forKey: .handle)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(did, forKey: .did)
            try container.encode(handle, forKey: .handle)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)
            let handleValue = try handle.toCBORValue()
            map = map.adding(key: "handle", value: handleValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case did
            case handle
        }
    }
}

public extension ATProtoClient.Com.Atproto.Admin {
    // MARK: - updateAccountHandle

    /// Administrative action to update an account's handle.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: The HTTP response code
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func updateAccountHandle(
        input: ComAtprotoAdminUpdateAccountHandle.Input

    ) async throws -> Int {
        let endpoint = "com.atproto.admin.updateAccountHandle"

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
        let serviceDID = await networkService.getServiceDID(for: "com.atproto.admin.updateAccountHandle")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (_, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        return response.statusCode
    }
}
