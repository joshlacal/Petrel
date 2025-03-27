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

            if let value = authFactorToken {
                try container.encode(value, forKey: .authFactorToken)
            }

            if let value = allowTakendown {
                try container.encode(value, forKey: .allowTakendown)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case identifier
            case password
            case authFactorToken
            case allowTakendown
        }
    }

    public struct Output: ATProtocolCodable {
        public let accessJwt: String

        public let refreshJwt: String

        public let handle: String

        public let did: String

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

            handle: String,

            did: String,

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

            handle = try container.decode(String.self, forKey: .handle)

            did = try container.decode(String.self, forKey: .did)

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

            if let value = didDoc {
                try container.encode(value, forKey: .didDoc)
            }

            if let value = email {
                try container.encode(value, forKey: .email)
            }

            if let value = emailConfirmed {
                try container.encode(value, forKey: .emailConfirmed)
            }

            if let value = emailAuthFactor {
                try container.encode(value, forKey: .emailAuthFactor)
            }

            if let value = active {
                try container.encode(value, forKey: .active)
            }

            if let value = status {
                try container.encode(value, forKey: .status)
            }
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
