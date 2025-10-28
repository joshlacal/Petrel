import Foundation

// lexicon: 1, id: com.atproto.server.describeServer

public enum ComAtprotoServerDescribeServer {
    public static let typeIdentifier = "com.atproto.server.describeServer"

    public struct Links: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "com.atproto.server.describeServer#links"
        public let privacyPolicy: URI?
        public let termsOfService: URI?

        // Standard initializer
        public init(
            privacyPolicy: URI?, termsOfService: URI?
        ) {
            self.privacyPolicy = privacyPolicy
            self.termsOfService = termsOfService
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                privacyPolicy = try container.decodeIfPresent(URI.self, forKey: .privacyPolicy)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'privacyPolicy': \(error)")

                throw error
            }
            do {
                termsOfService = try container.decodeIfPresent(URI.self, forKey: .termsOfService)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'termsOfService': \(error)")

                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(privacyPolicy, forKey: .privacyPolicy)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(termsOfService, forKey: .termsOfService)
        }

        public func hash(into hasher: inout Hasher) {
            if let value = privacyPolicy {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = termsOfService {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if privacyPolicy != other.privacyPolicy {
                return false
            }

            if termsOfService != other.termsOfService {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            if let value = privacyPolicy {
                // Encode optional property even if it's an empty array for CBOR

                let privacyPolicyValue = try value.toCBORValue()
                map = map.adding(key: "privacyPolicy", value: privacyPolicyValue)
            }

            if let value = termsOfService {
                // Encode optional property even if it's an empty array for CBOR

                let termsOfServiceValue = try value.toCBORValue()
                map = map.adding(key: "termsOfService", value: termsOfServiceValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case privacyPolicy
            case termsOfService
        }
    }

    public struct Contact: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "com.atproto.server.describeServer#contact"
        public let email: String?

        // Standard initializer
        public init(
            email: String?
        ) {
            self.email = email
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                email = try container.decodeIfPresent(String.self, forKey: .email)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'email': \(error)")

                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(email, forKey: .email)
        }

        public func hash(into hasher: inout Hasher) {
            if let value = email {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if email != other.email {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            if let value = email {
                // Encode optional property even if it's an empty array for CBOR

                let emailValue = try value.toCBORValue()
                map = map.adding(key: "email", value: emailValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case email
        }
    }

    public struct Output: ATProtocolCodable {
        public let inviteCodeRequired: Bool?

        public let phoneVerificationRequired: Bool?

        public let availableUserDomains: [String]

        public let links: Links?

        public let contact: Contact?

        public let did: DID

        // Standard public initializer
        public init(
            inviteCodeRequired: Bool? = nil,

            phoneVerificationRequired: Bool? = nil,

            availableUserDomains: [String],

            links: Links? = nil,

            contact: Contact? = nil,

            did: DID

        ) {
            self.inviteCodeRequired = inviteCodeRequired

            self.phoneVerificationRequired = phoneVerificationRequired

            self.availableUserDomains = availableUserDomains

            self.links = links

            self.contact = contact

            self.did = did
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            inviteCodeRequired = try container.decodeIfPresent(Bool.self, forKey: .inviteCodeRequired)

            phoneVerificationRequired = try container.decodeIfPresent(Bool.self, forKey: .phoneVerificationRequired)

            availableUserDomains = try container.decode([String].self, forKey: .availableUserDomains)

            links = try container.decodeIfPresent(Links.self, forKey: .links)

            contact = try container.decodeIfPresent(Contact.self, forKey: .contact)

            did = try container.decode(DID.self, forKey: .did)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(inviteCodeRequired, forKey: .inviteCodeRequired)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(phoneVerificationRequired, forKey: .phoneVerificationRequired)

            try container.encode(availableUserDomains, forKey: .availableUserDomains)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(links, forKey: .links)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(contact, forKey: .contact)

            try container.encode(did, forKey: .did)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            if let value = inviteCodeRequired {
                // Encode optional property even if it's an empty array for CBOR
                let inviteCodeRequiredValue = try value.toCBORValue()
                map = map.adding(key: "inviteCodeRequired", value: inviteCodeRequiredValue)
            }

            if let value = phoneVerificationRequired {
                // Encode optional property even if it's an empty array for CBOR
                let phoneVerificationRequiredValue = try value.toCBORValue()
                map = map.adding(key: "phoneVerificationRequired", value: phoneVerificationRequiredValue)
            }

            let availableUserDomainsValue = try availableUserDomains.toCBORValue()
            map = map.adding(key: "availableUserDomains", value: availableUserDomainsValue)

            if let value = links {
                // Encode optional property even if it's an empty array for CBOR
                let linksValue = try value.toCBORValue()
                map = map.adding(key: "links", value: linksValue)
            }

            if let value = contact {
                // Encode optional property even if it's an empty array for CBOR
                let contactValue = try value.toCBORValue()
                map = map.adding(key: "contact", value: contactValue)
            }

            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case inviteCodeRequired
            case phoneVerificationRequired
            case availableUserDomains
            case links
            case contact
            case did
        }
    }
}

public extension ATProtoClient.Com.Atproto.Server {
    // MARK: - describeServer

    /// Describes the server's account creation requirements and capabilities. Implemented by PDS.
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func describeServer() async throws -> (responseCode: Int, data: ComAtprotoServerDescribeServer.Output?) {
        let endpoint = "com.atproto.server.describeServer"

        let queryItems: [URLQueryItem]? = nil

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "com.atproto.server.describeServer")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        // Only decode response data if request was successful
        if (200 ... 299).contains(responseCode) {
            do {
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(ComAtprotoServerDescribeServer.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for com.atproto.server.describeServer: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
