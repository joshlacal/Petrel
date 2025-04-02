import Foundation

// lexicon: 1, id: com.atproto.admin.updateAccountHandle

public enum ComAtprotoAdminUpdateAccountHandle {
    public static let typeIdentifier = "com.atproto.admin.updateAccountHandle"
    public struct Input: ATProtocolCodable {
        public let did: DID
        public let handle: Handle

        // Standard public initializer
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

        private enum CodingKeys: String, CodingKey {
            case did
            case handle
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let didValue = try (did as? DAGCBOREncodable)?.toCBORValue() ?? did
            map = map.adding(key: "did", value: didValue)

            let handleValue = try (handle as? DAGCBOREncodable)?.toCBORValue() ?? handle
            map = map.adding(key: "handle", value: handleValue)

            return map
        }
    }
}

public extension ATProtoClient.Com.Atproto.Admin {
    /// Administrative action to update an account's handle.
    func updateAccountHandle(
        input: ComAtprotoAdminUpdateAccountHandle.Input

    ) async throws -> Int {
        let endpoint = "com.atproto.admin.updateAccountHandle"

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
