import Foundation

// lexicon: 1, id: com.atproto.server.createAccount

public enum ComAtprotoServerCreateAccount {
    public static let typeIdentifier = "com.atproto.server.createAccount"
    public struct Input: ATProtocolCodable {
        public let email: String?
        public let handle: String
        public let did: String?
        public let inviteCode: String?
        public let verificationCode: String?
        public let verificationPhone: String?
        public let password: String?
        public let recoveryKey: String?
        public let plcOp: ATProtocolValueContainer?

        // Standard public initializer
        public init(email: String? = nil, handle: String, did: String? = nil, inviteCode: String? = nil, verificationCode: String? = nil, verificationPhone: String? = nil, password: String? = nil, recoveryKey: String? = nil, plcOp: ATProtocolValueContainer? = nil) {
            self.email = email
            self.handle = handle
            self.did = did
            self.inviteCode = inviteCode
            self.verificationCode = verificationCode
            self.verificationPhone = verificationPhone
            self.password = password
            self.recoveryKey = recoveryKey
            self.plcOp = plcOp
        }
    }

    public struct Output: ATProtocolCodable {
        public let accessJwt: String

        public let refreshJwt: String

        public let handle: String

        public let did: String

        public let didDoc: DIDDocument?

        // Standard public initializer
        public init(
            accessJwt: String,

            refreshJwt: String,

            handle: String,

            did: String,

            didDoc: DIDDocument? = nil

        ) {
            self.accessJwt = accessJwt

            self.refreshJwt = refreshJwt

            self.handle = handle

            self.did = did

            self.didDoc = didDoc
        }
    }

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case invalidHandle = "InvalidHandle."
        case invalidPassword = "InvalidPassword."
        case invalidInviteCode = "InvalidInviteCode."
        case handleNotAvailable = "HandleNotAvailable."
        case unsupportedDomain = "UnsupportedDomain."
        case unresolvableDid = "UnresolvableDid."
        case incompatibleDidDoc = "IncompatibleDidDoc."
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.Com.Atproto.Server {
    /// Create an account. Implemented by PDS.
    func createAccount(
        input: ComAtprotoServerCreateAccount.Input

    ) async throws -> (responseCode: Int, data: ComAtprotoServerCreateAccount.Output?) {
        let endpoint = "com.atproto.server.createAccount"

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
        let decodedData = try? decoder.decode(ComAtprotoServerCreateAccount.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
