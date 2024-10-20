import Foundation
import ZippyJSON

// lexicon: 1, id: com.atproto.server.createSession

public enum ComAtprotoServerCreateSession {
    public static let typeIdentifier = "com.atproto.server.createSession"
    public struct Input: ATProtocolCodable {
        public let identifier: String
        public let password: String
        public let authFactorToken: String?

        // Standard public initializer
        public init(identifier: String, password: String, authFactorToken: String? = nil) {
            self.identifier = identifier
            self.password = password
            self.authFactorToken = authFactorToken
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

        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(ComAtprotoServerCreateSession.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
