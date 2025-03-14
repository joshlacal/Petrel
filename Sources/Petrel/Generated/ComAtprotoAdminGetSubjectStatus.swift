import Foundation

// lexicon: 1, id: com.atproto.admin.getSubjectStatus

public enum ComAtprotoAdminGetSubjectStatus {
    public static let typeIdentifier = "com.atproto.admin.getSubjectStatus"
    public struct Parameters: Parametrizable {
        public let did: String?
        public let uri: ATProtocolURI?
        public let blob: String?

        public init(
            did: String? = nil,
            uri: ATProtocolURI? = nil,
            blob: String? = nil
        ) {
            self.did = did
            self.uri = uri
            self.blob = blob
        }
    }

    public struct Output: ATProtocolCodable {
        public let subject: OutputSubjectUnion

        public let takedown: ComAtprotoAdminDefs.StatusAttr?

        public let deactivated: ComAtprotoAdminDefs.StatusAttr?

        // Standard public initializer
        public init(
            subject: OutputSubjectUnion,

            takedown: ComAtprotoAdminDefs.StatusAttr? = nil,

            deactivated: ComAtprotoAdminDefs.StatusAttr? = nil

        ) {
            self.subject = subject

            self.takedown = takedown

            self.deactivated = deactivated
        }
    }

    public enum OutputSubjectUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, PendingDataLoadable, Equatable {
        case comAtprotoAdminDefsRepoRef(ComAtprotoAdminDefs.RepoRef)
        case comAtprotoRepoStrongRef(ComAtprotoRepoStrongRef)
        case comAtprotoAdminDefsRepoBlobRef(ComAtprotoAdminDefs.RepoBlobRef)
        case unexpected(ATProtocolValueContainer)

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            switch typeValue {
            case "com.atproto.admin.defs#repoRef":
                let value = try ComAtprotoAdminDefs.RepoRef(from: decoder)
                self = .comAtprotoAdminDefsRepoRef(value)
            case "com.atproto.repo.strongRef":
                let value = try ComAtprotoRepoStrongRef(from: decoder)
                self = .comAtprotoRepoStrongRef(value)
            case "com.atproto.admin.defs#repoBlobRef":
                let value = try ComAtprotoAdminDefs.RepoBlobRef(from: decoder)
                self = .comAtprotoAdminDefsRepoBlobRef(value)
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .comAtprotoAdminDefsRepoRef(value):
                try container.encode("com.atproto.admin.defs#repoRef", forKey: .type)
                try value.encode(to: encoder)
            case let .comAtprotoRepoStrongRef(value):
                try container.encode("com.atproto.repo.strongRef", forKey: .type)
                try value.encode(to: encoder)
            case let .comAtprotoAdminDefsRepoBlobRef(value):
                try container.encode("com.atproto.admin.defs#repoBlobRef", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .comAtprotoAdminDefsRepoRef(value):
                hasher.combine("com.atproto.admin.defs#repoRef")
                hasher.combine(value)
            case let .comAtprotoRepoStrongRef(value):
                hasher.combine("com.atproto.repo.strongRef")
                hasher.combine(value)
            case let .comAtprotoAdminDefsRepoBlobRef(value):
                hasher.combine("com.atproto.admin.defs#repoBlobRef")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
            case rawContent = "_rawContent"
        }

        public static func == (lhs: OutputSubjectUnion, rhs: OutputSubjectUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .comAtprotoAdminDefsRepoRef(lhsValue),
                .comAtprotoAdminDefsRepoRef(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .comAtprotoRepoStrongRef(lhsValue),
                .comAtprotoRepoStrongRef(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .comAtprotoAdminDefsRepoBlobRef(lhsValue),
                .comAtprotoAdminDefsRepoBlobRef(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard other is OutputSubjectUnion else { return false }
            return self == (other as! OutputSubjectUnion)
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .comAtprotoAdminDefsRepoRef(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .comAtprotoRepoStrongRef(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .comAtprotoAdminDefsRepoBlobRef(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case let .comAtprotoAdminDefsRepoRef(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ComAtprotoAdminDefs.RepoRef.self, from: jsonData)
                    {
                        self = .comAtprotoAdminDefsRepoRef(decodedValue)
                    }
                }
            case let .comAtprotoRepoStrongRef(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ComAtprotoRepoStrongRef.self, from: jsonData)
                    {
                        self = .comAtprotoRepoStrongRef(decodedValue)
                    }
                }
            case let .comAtprotoAdminDefsRepoBlobRef(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ComAtprotoAdminDefs.RepoBlobRef.self, from: jsonData)
                    {
                        self = .comAtprotoAdminDefsRepoBlobRef(decodedValue)
                    }
                }
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }
}

public extension ATProtoClient.Com.Atproto.Admin {
    /// Get the service-specific admin status of a subject (account, record, or blob).
    func getSubjectStatus(input: ComAtprotoAdminGetSubjectStatus.Parameters) async throws -> (responseCode: Int, data: ComAtprotoAdminGetSubjectStatus.Output?) {
        let endpoint = "com.atproto.admin.getSubjectStatus"

        let queryItems = input.asQueryItems()

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
        let decodedData = try? decoder.decode(ComAtprotoAdminGetSubjectStatus.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
