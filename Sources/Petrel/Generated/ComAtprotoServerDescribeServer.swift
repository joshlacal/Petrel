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
                LogManager.logError("Decoding error for property 'privacyPolicy': \(error)")
                throw error
            }
            do {
                termsOfService = try container.decodeIfPresent(URI.self, forKey: .termsOfService)

            } catch {
                LogManager.logError("Decoding error for property 'termsOfService': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            if let value = privacyPolicy {
                try container.encode(value, forKey: .privacyPolicy)
            }

            if let value = termsOfService {
                try container.encode(value, forKey: .termsOfService)
            }
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
                LogManager.logError("Decoding error for property 'email': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            if let value = email {
                try container.encode(value, forKey: .email)
            }
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

        public let did: String

        // Standard public initializer
        public init(
            inviteCodeRequired: Bool? = nil,

            phoneVerificationRequired: Bool? = nil,

            availableUserDomains: [String],

            links: Links? = nil,

            contact: Contact? = nil,

            did: String

        ) {
            self.inviteCodeRequired = inviteCodeRequired

            self.phoneVerificationRequired = phoneVerificationRequired

            self.availableUserDomains = availableUserDomains

            self.links = links

            self.contact = contact

            self.did = did
        }
    }
}

public extension ATProtoClient.Com.Atproto.Server {
    /// Describes the server's account creation requirements and capabilities. Implemented by PDS.
    func describeServer() async throws -> (responseCode: Int, data: ComAtprotoServerDescribeServer.Output?) {
        let endpoint = "com.atproto.server.describeServer"

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
        let decodedData = try? decoder.decode(ComAtprotoServerDescribeServer.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
