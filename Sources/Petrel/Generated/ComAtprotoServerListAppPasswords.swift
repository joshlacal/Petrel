import Foundation

// lexicon: 1, id: com.atproto.server.listAppPasswords

public enum ComAtprotoServerListAppPasswords {
    public static let typeIdentifier = "com.atproto.server.listAppPasswords"

    public struct AppPassword: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "com.atproto.server.listAppPasswords#appPassword"
        public let name: String
        public let createdAt: ATProtocolDate
        public let privileged: Bool?

        // Standard initializer
        public init(
            name: String, createdAt: ATProtocolDate, privileged: Bool?
        ) {
            self.name = name
            self.createdAt = createdAt
            self.privileged = privileged
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                name = try container.decode(String.self, forKey: .name)

            } catch {
                LogManager.logError("Decoding error for property 'name': \(error)")
                throw error
            }
            do {
                createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)

            } catch {
                LogManager.logError("Decoding error for property 'createdAt': \(error)")
                throw error
            }
            do {
                privileged = try container.decodeIfPresent(Bool.self, forKey: .privileged)

            } catch {
                LogManager.logError("Decoding error for property 'privileged': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(name, forKey: .name)

            try container.encode(createdAt, forKey: .createdAt)

            if let value = privileged {
                try container.encode(value, forKey: .privileged)
            }
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(name)
            hasher.combine(createdAt)
            if let value = privileged {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if name != other.name {
                return false
            }

            if createdAt != other.createdAt {
                return false
            }

            if privileged != other.privileged {
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

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            let nameValue = try (name as? DAGCBOREncodable)?.toCBORValue() ?? name
            map = map.adding(key: "name", value: nameValue)

            let createdAtValue = try (createdAt as? DAGCBOREncodable)?.toCBORValue() ?? createdAt
            map = map.adding(key: "createdAt", value: createdAtValue)

            if let value = privileged {
                let privilegedValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "privileged", value: privilegedValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case name
            case createdAt
            case privileged
        }
    }

    public struct Output: ATProtocolCodable {
        public let passwords: [AppPassword]

        // Standard public initializer
        public init(
            passwords: [AppPassword]

        ) {
            self.passwords = passwords
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            passwords = try container.decode([AppPassword].self, forKey: .passwords)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(passwords, forKey: .passwords)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Add fields in lexicon-defined order

            let passwordsValue = try (passwords as? DAGCBOREncodable)?.toCBORValue() ?? passwords
            map = map.adding(key: "passwords", value: passwordsValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case passwords
        }
    }

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case accountTakedown = "AccountTakedown."
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.Com.Atproto.Server {
    /// List all App Passwords.
    func listAppPasswords() async throws -> (responseCode: Int, data: ComAtprotoServerListAppPasswords.Output?) {
        let endpoint = "com.atproto.server.listAppPasswords"

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
        let decodedData = try? decoder.decode(ComAtprotoServerListAppPasswords.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
