import Foundation

// lexicon: 1, id: com.atproto.server.getSession

public enum ComAtprotoServerGetSession {
    public static let typeIdentifier = "com.atproto.server.getSession"

    public struct Output: ATProtocolCodable {
        public let handle: Handle

        public let did: DID

        public let email: String?

        public let emailConfirmed: Bool?

        public let emailAuthFactor: Bool?

        public let didDoc: DIDDocument?

        public let active: Bool?

        public let status: String?

        // Standard public initializer
        public init(
            handle: Handle,

            did: DID,

            email: String? = nil,

            emailConfirmed: Bool? = nil,

            emailAuthFactor: Bool? = nil,

            didDoc: DIDDocument? = nil,

            active: Bool? = nil,

            status: String? = nil

        ) {
            self.handle = handle

            self.did = did

            self.email = email

            self.emailConfirmed = emailConfirmed

            self.emailAuthFactor = emailAuthFactor

            self.didDoc = didDoc

            self.active = active

            self.status = status
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            handle = try container.decode(Handle.self, forKey: .handle)

            did = try container.decode(DID.self, forKey: .did)

            email = try container.decodeIfPresent(String.self, forKey: .email)

            emailConfirmed = try container.decodeIfPresent(Bool.self, forKey: .emailConfirmed)

            emailAuthFactor = try container.decodeIfPresent(Bool.self, forKey: .emailAuthFactor)

            didDoc = try container.decodeIfPresent(DIDDocument.self, forKey: .didDoc)

            active = try container.decodeIfPresent(Bool.self, forKey: .active)

            status = try container.decodeIfPresent(String.self, forKey: .status)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(handle, forKey: .handle)

            try container.encode(did, forKey: .did)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(email, forKey: .email)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(emailConfirmed, forKey: .emailConfirmed)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(emailAuthFactor, forKey: .emailAuthFactor)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(didDoc, forKey: .didDoc)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(active, forKey: .active)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(status, forKey: .status)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let handleValue = try (handle as? DAGCBOREncodable)?.toCBORValue() ?? handle
            map = map.adding(key: "handle", value: handleValue)

            let didValue = try (did as? DAGCBOREncodable)?.toCBORValue() ?? did
            map = map.adding(key: "did", value: didValue)

            if let value = email {
                // Encode optional property even if it's an empty array for CBOR

                let emailValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "email", value: emailValue)
            }

            if let value = emailConfirmed {
                // Encode optional property even if it's an empty array for CBOR

                let emailConfirmedValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "emailConfirmed", value: emailConfirmedValue)
            }

            if let value = emailAuthFactor {
                // Encode optional property even if it's an empty array for CBOR

                let emailAuthFactorValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "emailAuthFactor", value: emailAuthFactorValue)
            }

            if let value = didDoc {
                // Encode optional property even if it's an empty array for CBOR

                let didDocValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "didDoc", value: didDocValue)
            }

            if let value = active {
                // Encode optional property even if it's an empty array for CBOR

                let activeValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "active", value: activeValue)
            }

            if let value = status {
                // Encode optional property even if it's an empty array for CBOR

                let statusValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "status", value: statusValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case handle
            case did
            case email
            case emailConfirmed
            case emailAuthFactor
            case didDoc
            case active
            case status
        }
    }
}

public extension ATProtoClient.Com.Atproto.Server {
    /// Get information about the current auth session. Requires auth.
    func getSession() async throws -> (responseCode: Int, data: ComAtprotoServerGetSession.Output?) {
        let endpoint = "com.atproto.server.getSession"

        let queryItems: [URLQueryItem]? = nil

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
        let decodedData = try? decoder.decode(ComAtprotoServerGetSession.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
