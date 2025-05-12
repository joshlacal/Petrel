import Foundation

// lexicon: 1, id: com.atproto.server.createAccount

public enum ComAtprotoServerCreateAccount {
    public static let typeIdentifier = "com.atproto.server.createAccount"
    public struct Input: ATProtocolCodable {
        public let email: String?
        public let handle: Handle
        public let did: DID?
        public let inviteCode: String?
        public let verificationCode: String?
        public let verificationPhone: String?
        public let password: String?
        public let recoveryKey: String?
        public let plcOp: ATProtocolValueContainer?

        // Standard public initializer
        public init(email: String? = nil, handle: Handle, did: DID? = nil, inviteCode: String? = nil, verificationCode: String? = nil, verificationPhone: String? = nil, password: String? = nil, recoveryKey: String? = nil, plcOp: ATProtocolValueContainer? = nil) {
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

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            email = try container.decodeIfPresent(String.self, forKey: .email)

            handle = try container.decode(Handle.self, forKey: .handle)

            did = try container.decodeIfPresent(DID.self, forKey: .did)

            inviteCode = try container.decodeIfPresent(String.self, forKey: .inviteCode)

            verificationCode = try container.decodeIfPresent(String.self, forKey: .verificationCode)

            verificationPhone = try container.decodeIfPresent(String.self, forKey: .verificationPhone)

            password = try container.decodeIfPresent(String.self, forKey: .password)

            recoveryKey = try container.decodeIfPresent(String.self, forKey: .recoveryKey)

            plcOp = try container.decodeIfPresent(ATProtocolValueContainer.self, forKey: .plcOp)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(email, forKey: .email)

            try container.encode(handle, forKey: .handle)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(did, forKey: .did)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(inviteCode, forKey: .inviteCode)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(verificationCode, forKey: .verificationCode)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(verificationPhone, forKey: .verificationPhone)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(password, forKey: .password)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(recoveryKey, forKey: .recoveryKey)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(plcOp, forKey: .plcOp)
        }

        private enum CodingKeys: String, CodingKey {
            case email
            case handle
            case did
            case inviteCode
            case verificationCode
            case verificationPhone
            case password
            case recoveryKey
            case plcOp
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            if let value = email {
                // Encode optional property even if it's an empty array for CBOR
                let emailValue = try value.toCBORValue()
                map = map.adding(key: "email", value: emailValue)
            }

            let handleValue = try handle.toCBORValue()
            map = map.adding(key: "handle", value: handleValue)

            if let value = did {
                // Encode optional property even if it's an empty array for CBOR
                let didValue = try value.toCBORValue()
                map = map.adding(key: "did", value: didValue)
            }

            if let value = inviteCode {
                // Encode optional property even if it's an empty array for CBOR
                let inviteCodeValue = try value.toCBORValue()
                map = map.adding(key: "inviteCode", value: inviteCodeValue)
            }

            if let value = verificationCode {
                // Encode optional property even if it's an empty array for CBOR
                let verificationCodeValue = try value.toCBORValue()
                map = map.adding(key: "verificationCode", value: verificationCodeValue)
            }

            if let value = verificationPhone {
                // Encode optional property even if it's an empty array for CBOR
                let verificationPhoneValue = try value.toCBORValue()
                map = map.adding(key: "verificationPhone", value: verificationPhoneValue)
            }

            if let value = password {
                // Encode optional property even if it's an empty array for CBOR
                let passwordValue = try value.toCBORValue()
                map = map.adding(key: "password", value: passwordValue)
            }

            if let value = recoveryKey {
                // Encode optional property even if it's an empty array for CBOR
                let recoveryKeyValue = try value.toCBORValue()
                map = map.adding(key: "recoveryKey", value: recoveryKeyValue)
            }

            if let value = plcOp {
                // Encode optional property even if it's an empty array for CBOR
                let plcOpValue = try value.toCBORValue()
                map = map.adding(key: "plcOp", value: plcOpValue)
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

        // Standard public initializer
        public init(
            accessJwt: String,

            refreshJwt: String,

            handle: Handle,

            did: DID,

            didDoc: DIDDocument? = nil

        ) {
            self.accessJwt = accessJwt

            self.refreshJwt = refreshJwt

            self.handle = handle

            self.did = did

            self.didDoc = didDoc
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            accessJwt = try container.decode(String.self, forKey: .accessJwt)

            refreshJwt = try container.decode(String.self, forKey: .refreshJwt)

            handle = try container.decode(Handle.self, forKey: .handle)

            did = try container.decode(DID.self, forKey: .did)

            didDoc = try container.decodeIfPresent(DIDDocument.self, forKey: .didDoc)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(accessJwt, forKey: .accessJwt)

            try container.encode(refreshJwt, forKey: .refreshJwt)

            try container.encode(handle, forKey: .handle)

            try container.encode(did, forKey: .did)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(didDoc, forKey: .didDoc)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let accessJwtValue = try accessJwt.toCBORValue()
            map = map.adding(key: "accessJwt", value: accessJwtValue)

            let refreshJwtValue = try refreshJwt.toCBORValue()
            map = map.adding(key: "refreshJwt", value: refreshJwtValue)

            let handleValue = try handle.toCBORValue()
            map = map.adding(key: "handle", value: handleValue)

            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)

            if let value = didDoc {
                // Encode optional property even if it's an empty array for CBOR
                let didDocValue = try value.toCBORValue()
                map = map.adding(key: "didDoc", value: didDocValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case accessJwt
            case refreshJwt
            case handle
            case did
            case didDoc
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
    // MARK: - createAccount

    /// Create an account. Implemented by PDS.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func createAccount(
        input: ComAtprotoServerCreateAccount.Input

    ) async throws -> (responseCode: Int, data: ComAtprotoServerCreateAccount.Output?) {
        let endpoint = "com.atproto.server.createAccount"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        headers["Accept"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        let (responseData, response) = try await networkService.performRequest(urlRequest)
        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(ComAtprotoServerCreateAccount.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
