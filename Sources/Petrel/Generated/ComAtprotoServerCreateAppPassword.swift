import Foundation
internal import ZippyJSON

// lexicon: 1, id: com.atproto.server.createAppPassword

public enum ComAtprotoServerCreateAppPassword {
    public static let typeIdentifier = "com.atproto.server.createAppPassword"

    public struct AppPassword: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "com.atproto.server.createAppPassword#appPassword"
        public let name: String
        public let password: String
        public let createdAt: ATProtocolDate
        public let privileged: Bool?

        // Standard initializer
        public init(
            name: String, password: String, createdAt: ATProtocolDate, privileged: Bool?
        ) {
            self.name = name
            self.password = password
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
                password = try container.decode(String.self, forKey: .password)

            } catch {
                LogManager.logError("Decoding error for property 'password': \(error)")
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

            try container.encode(password, forKey: .password)

            try container.encode(createdAt, forKey: .createdAt)

            if let value = privileged {
                try container.encode(value, forKey: .privileged)
            }
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(name)
            hasher.combine(password)
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

            if password != other.password {
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

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case name
            case password
            case createdAt
            case privileged
        }
    }

    public struct Input: ATProtocolCodable {
        public let name: String
        public let privileged: Bool?

        // Standard public initializer
        public init(name: String, privileged: Bool? = nil) {
            self.name = name
            self.privileged = privileged
        }
    }

    public typealias Output = AppPassword

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case accountTakedown = "AccountTakedown."
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.Com.Atproto.Server {
    /// Create an App Password.
    func createAppPassword(
        input: ComAtprotoServerCreateAppPassword.Input,

        duringInitialSetup: Bool = false
    ) async throws -> (responseCode: Int, data: ComAtprotoServerCreateAppPassword.Output?) {
        let endpoint = "/com.atproto.server.createAppPassword"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: ["Content-Type": "application/json"],
            body: requestData,
            queryItems: nil
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest, retryCount: 0, duringInitialSetup: duringInitialSetup)
        let responseCode = response.statusCode

        let decodedData = try? ZippyJSONDecoder().decode(ComAtprotoServerCreateAppPassword.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
