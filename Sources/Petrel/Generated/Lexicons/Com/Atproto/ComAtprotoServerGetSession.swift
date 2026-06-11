import Foundation

// lexicon: 1, id: com.atproto.server.getSession

public enum ComAtprotoServerGetSession {
    public static let typeIdentifier = "com.atproto.server.getSession"

    public struct Output: ATProtocolCodable {
        public let handle: Handle

        public let did: DID

        public let didDoc: DIDDocument?

        public let email: String?

        public let emailConfirmed: Bool?

        public let emailAuthFactor: Bool?

        public let active: Bool?

        public let status: String?

        /// Standard public initializer
        public init(
            handle: Handle,

            did: DID,

            didDoc: DIDDocument? = nil,

            email: String? = nil,

            emailConfirmed: Bool? = nil,

            emailAuthFactor: Bool? = nil,

            active: Bool? = nil,

            status: String? = nil

        ) {
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

            handle = try container.decode(Handle.self, forKey: .handle)

            did = try container.decode(DID.self, forKey: .did)

            do {
                didDoc = try container.decodeIfPresent(DIDDocument.self, forKey: .didDoc)
            } catch {
                // Forward compatibility: a malformed optional field must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'didDoc' — degrading to nil: \(error)")
                didDoc = nil
            }

            do {
                email = try container.decodeIfPresent(String.self, forKey: .email)
            } catch {
                // Forward compatibility: a malformed optional field must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'email' — degrading to nil: \(error)")
                email = nil
            }

            do {
                emailConfirmed = try container.decodeIfPresent(Bool.self, forKey: .emailConfirmed)
            } catch {
                // Forward compatibility: a malformed optional field must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'emailConfirmed' — degrading to nil: \(error)")
                emailConfirmed = nil
            }

            do {
                emailAuthFactor = try container.decodeIfPresent(Bool.self, forKey: .emailAuthFactor)
            } catch {
                // Forward compatibility: a malformed optional field must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'emailAuthFactor' — degrading to nil: \(error)")
                emailAuthFactor = nil
            }

            do {
                active = try container.decodeIfPresent(Bool.self, forKey: .active)
            } catch {
                // Forward compatibility: a malformed optional field must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'active' — degrading to nil: \(error)")
                active = nil
            }

            do {
                status = try container.decodeIfPresent(String.self, forKey: .status)
            } catch {
                // Forward compatibility: a malformed optional field must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'status' — degrading to nil: \(error)")
                status = nil
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

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

            let handleValue = try handle.toCBORValue()
            map = map.adding(key: "handle", value: handleValue)

            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)

            if let value = didDoc {
                // Encode optional property even if it's an empty array for CBOR
                let didDocValue = try value.toCBORValue()
                map = map.adding(key: "didDoc", value: didDocValue)
            }

            if let value = email {
                // Encode optional property even if it's an empty array for CBOR
                let emailValue = try value.toCBORValue()
                map = map.adding(key: "email", value: emailValue)
            }

            if let value = emailConfirmed {
                // Encode optional property even if it's an empty array for CBOR
                let emailConfirmedValue = try value.toCBORValue()
                map = map.adding(key: "emailConfirmed", value: emailConfirmedValue)
            }

            if let value = emailAuthFactor {
                // Encode optional property even if it's an empty array for CBOR
                let emailAuthFactorValue = try value.toCBORValue()
                map = map.adding(key: "emailAuthFactor", value: emailAuthFactorValue)
            }

            if let value = active {
                // Encode optional property even if it's an empty array for CBOR
                let activeValue = try value.toCBORValue()
                map = map.adding(key: "active", value: activeValue)
            }

            if let value = status {
                // Encode optional property even if it's an empty array for CBOR
                let statusValue = try value.toCBORValue()
                map = map.adding(key: "status", value: statusValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
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
}

public extension ATProtoClient.Com.Atproto.Server {
    // MARK: - getSession

    /// Get information about the current auth session. Requires auth.
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getSession() async throws -> (responseCode: Int, data: ComAtprotoServerGetSession.Output?) {
        let endpoint = "com.atproto.server.getSession"

        let queryItems: [URLQueryItem]? = nil

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "com.atproto.server.getSession")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        // Only validate Content-Type and decode on success. Error responses
        // (4xx/5xx) may have missing or different Content-Type headers and
        // are handled via the status code / structured error parser below.
        if (200 ... 299).contains(responseCode) {
            guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
                throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
            }

            if !contentType.lowercased().contains("application/json") {
                throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
            }

            do {
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(ComAtprotoServerGetSession.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for com.atproto.server.getSession: \(error)")
                return (responseCode, nil)
            }
        } else {
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
