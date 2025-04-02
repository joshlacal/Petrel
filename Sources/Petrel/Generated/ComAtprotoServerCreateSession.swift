import Foundation

// lexicon: 1, id: com.atproto.server.createSession

public enum ComAtprotoServerCreateSession {
    public static let typeIdentifier = "com.atproto.server.createSession"
    public struct Input: ATProtocolCodable {
        public let identifier: String
        public let password: String
        public let authFactorToken: String?
        public let allowTakendown: Bool?

        // Standard public initializer
        public init(identifier: String, password: String, authFactorToken: String? = nil, allowTakendown: Bool? = nil) {
            self.identifier = identifier
            self.password = password
            self.authFactorToken = authFactorToken
            self.allowTakendown = allowTakendown
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            identifier = try container.decode(String.self, forKey: .identifier)

            password = try container.decode(String.self, forKey: .password)

            authFactorToken = try container.decodeIfPresent(String.self, forKey: .authFactorToken)

            allowTakendown = try container.decodeIfPresent(Bool.self, forKey: .allowTakendown)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(identifier, forKey: .identifier)

            try container.encode(password, forKey: .password)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(authFactorToken, forKey: .authFactorToken)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(allowTakendown, forKey: .allowTakendown)
        }

        private enum CodingKeys: String, CodingKey {
            case identifier
            case password
            case authFactorToken
            case allowTakendown
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let identifierValue = try (identifier as? DAGCBOREncodable)?.toCBORValue() ?? identifier
            map = map.adding(key: "identifier", value: identifierValue)

            let passwordValue = try (password as? DAGCBOREncodable)?.toCBORValue() ?? password
            map = map.adding(key: "password", value: passwordValue)

            if let value = authFactorToken {
                // Encode optional property even if it's an empty array for CBOR

                let authFactorTokenValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "authFactorToken", value: authFactorTokenValue)
            }

            if let value = allowTakendown {
                // Encode optional property even if it's an empty array for CBOR

                let allowTakendownValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "allowTakendown", value: allowTakendownValue)
            }

            return map
        }
    }

    public struct Output: ATProtocolCodable {
        public let accessJwt: String

        public let refreshJwt: String

        public let handle: Handle

        public let did: DID

        public let didDoc: DIDDocument?

        public let email: String?

        public let emailConfirmed: Bool?

        public let emailAuthFactor: Bool?

        public let active: Bool?

        public let status: String?

        // Standard public initializer
        public init(
            accessJwt: String,

            refreshJwt: String,

            handle: Handle,

            did: DID,

            didDoc: DIDDocument? = nil,

            email: String? = nil,

            emailConfirmed: Bool? = nil,

            emailAuthFactor: Bool? = nil,

            active: Bool? = nil,

            status: String? = nil

        ) {
            self.accessJwt = accessJwt

            self.refreshJwt = refreshJwt

            self.handle = handle

            self.did = did

            self.didDoc = didDoc

            self.email = email

            self.emailConfirmed = emailConfirmed

            self.emailAuthFactor = emailAuthFactor

            self.active = active

            self.status = status
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            accessJwt = try container.decode(String.self, forKey: .accessJwt)

            refreshJwt = try container.decode(String.self, forKey: .refreshJwt)

            handle = try container.decode(Handle.self, forKey: .handle)

            did = try container.decode(DID.self, forKey: .did)

            didDoc = try container.decodeIfPresent(DIDDocument.self, forKey: .didDoc)

            email = try container.decodeIfPresent(String.self, forKey: .email)

            emailConfirmed = try container.decodeIfPresent(Bool.self, forKey: .emailConfirmed)

            emailAuthFactor = try container.decodeIfPresent(Bool.self, forKey: .emailAuthFactor)

            active = try container.decodeIfPresent(Bool.self, forKey: .active)

            status = try container.decodeIfPresent(String.self, forKey: .status)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(accessJwt, forKey: .accessJwt)

            try container.encode(refreshJwt, forKey: .refreshJwt)

            try container.encode(handle, forKey: .handle)

            try container.encode(did, forKey: .did)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(didDoc, forKey: .didDoc)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(email, forKey: .email)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(emailConfirmed, forKey: .emailConfirmed)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(emailAuthFactor, forKey: .emailAuthFactor)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(active, forKey: .active)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(status, forKey: .status)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let accessJwtValue = try (accessJwt as? DAGCBOREncodable)?.toCBORValue() ?? accessJwt
            map = map.adding(key: "accessJwt", value: accessJwtValue)

            let refreshJwtValue = try (refreshJwt as? DAGCBOREncodable)?.toCBORValue() ?? refreshJwt
            map = map.adding(key: "refreshJwt", value: refreshJwtValue)

            let handleValue = try (handle as? DAGCBOREncodable)?.toCBORValue() ?? handle
            map = map.adding(key: "handle", value: handleValue)

            let didValue = try (did as? DAGCBOREncodable)?.toCBORValue() ?? did
            map = map.adding(key: "did", value: didValue)

            if let value = didDoc {
                // Encode optional property even if it's an empty array for CBOR

                let didDocValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "didDoc", value: didDocValue)
            }

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
            case accessJwt
            case refreshJwt
            case handle
            case did
            case didDoc
            case email
            case emailConfirmed
            case emailAuthFactor
            case active
            case status
        }
    }

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case accountTakedown = "AccountTakedown."
        case authFactorTokenRequired = "AuthFactorTokenRequired."
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.Com.Atproto.Server {
    /// Create an authentication session.
    func createSession(
        input: ComAtprotoServerCreateSession.Input

    ) async throws -> (responseCode: Int, data: ComAtprotoServerCreateSession.Output?) {
        let endpoint = "com.atproto.server.createSession"

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

        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(ComAtprotoServerCreateSession.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
