import Foundation

// lexicon: 1, id: com.atproto.admin.updateSubjectStatus

public enum ComAtprotoAdminUpdateSubjectStatus {
    public static let typeIdentifier = "com.atproto.admin.updateSubjectStatus"
    public struct Input: ATProtocolCodable {
        public let subject: InputSubjectUnion
        public let takedown: ComAtprotoAdminDefs.StatusAttr?
        public let deactivated: ComAtprotoAdminDefs.StatusAttr?

        // Standard public initializer
        public init(subject: InputSubjectUnion, takedown: ComAtprotoAdminDefs.StatusAttr? = nil, deactivated: ComAtprotoAdminDefs.StatusAttr? = nil) {
            self.subject = subject
            self.takedown = takedown
            self.deactivated = deactivated
        }
    }

    public struct Output: ATProtocolCodable {
        public let subject: OutputSubjectUnion

        public let takedown: ComAtprotoAdminDefs.StatusAttr?

        // Standard public initializer
        public init(
            subject: OutputSubjectUnion,

            takedown: ComAtprotoAdminDefs.StatusAttr? = nil

        ) {
            self.subject = subject

            self.takedown = takedown
        }
    }

    public enum InputSubjectUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, PendingDataLoadable, Equatable {
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

        public static func == (lhs: InputSubjectUnion, rhs: InputSubjectUnion) -> Bool {
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
            guard let otherValue = other as? InputSubjectUnion else { return false }
            return self == otherValue
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
                // Handle nested PendingDataLoadable values
                if let loadableValue = value as? PendingDataLoadable, loadableValue.hasPendingData {
                    // Create a mutable copy we can work with
                    var mutableLoadable = loadableValue
                    await mutableLoadable.loadPendingData()

                    // Only try to cast back if the original value was of the expected type
                    if let originalValue = value as? ComAtprotoAdminDefs.RepoRef,
                       let updatedValue = mutableLoadable as? ComAtprotoAdminDefs.RepoRef
                    {
                        self = .comAtprotoAdminDefsRepoRef(updatedValue)
                    }
                }
            case let .comAtprotoRepoStrongRef(value):
                // Handle nested PendingDataLoadable values
                if let loadableValue = value as? PendingDataLoadable, loadableValue.hasPendingData {
                    // Create a mutable copy we can work with
                    var mutableLoadable = loadableValue
                    await mutableLoadable.loadPendingData()

                    // Only try to cast back if the original value was of the expected type
                    if let originalValue = value as? ComAtprotoRepoStrongRef,
                       let updatedValue = mutableLoadable as? ComAtprotoRepoStrongRef
                    {
                        self = .comAtprotoRepoStrongRef(updatedValue)
                    }
                }
            case let .comAtprotoAdminDefsRepoBlobRef(value):
                // Handle nested PendingDataLoadable values
                if let loadableValue = value as? PendingDataLoadable, loadableValue.hasPendingData {
                    // Create a mutable copy we can work with
                    var mutableLoadable = loadableValue
                    await mutableLoadable.loadPendingData()

                    // Only try to cast back if the original value was of the expected type
                    if let originalValue = value as? ComAtprotoAdminDefs.RepoBlobRef,
                       let updatedValue = mutableLoadable as? ComAtprotoAdminDefs.RepoBlobRef
                    {
                        self = .comAtprotoAdminDefsRepoBlobRef(updatedValue)
                    }
                }
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
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
            guard let otherValue = other as? OutputSubjectUnion else { return false }
            return self == otherValue
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
                // Handle nested PendingDataLoadable values
                if let loadableValue = value as? PendingDataLoadable, loadableValue.hasPendingData {
                    // Create a mutable copy we can work with
                    var mutableLoadable = loadableValue
                    await mutableLoadable.loadPendingData()

                    // Only try to cast back if the original value was of the expected type
                    if let originalValue = value as? ComAtprotoAdminDefs.RepoRef,
                       let updatedValue = mutableLoadable as? ComAtprotoAdminDefs.RepoRef
                    {
                        self = .comAtprotoAdminDefsRepoRef(updatedValue)
                    }
                }
            case let .comAtprotoRepoStrongRef(value):
                // Handle nested PendingDataLoadable values
                if let loadableValue = value as? PendingDataLoadable, loadableValue.hasPendingData {
                    // Create a mutable copy we can work with
                    var mutableLoadable = loadableValue
                    await mutableLoadable.loadPendingData()

                    // Only try to cast back if the original value was of the expected type
                    if let originalValue = value as? ComAtprotoRepoStrongRef,
                       let updatedValue = mutableLoadable as? ComAtprotoRepoStrongRef
                    {
                        self = .comAtprotoRepoStrongRef(updatedValue)
                    }
                }
            case let .comAtprotoAdminDefsRepoBlobRef(value):
                // Handle nested PendingDataLoadable values
                if let loadableValue = value as? PendingDataLoadable, loadableValue.hasPendingData {
                    // Create a mutable copy we can work with
                    var mutableLoadable = loadableValue
                    await mutableLoadable.loadPendingData()

                    // Only try to cast back if the original value was of the expected type
                    if let originalValue = value as? ComAtprotoAdminDefs.RepoBlobRef,
                       let updatedValue = mutableLoadable as? ComAtprotoAdminDefs.RepoBlobRef
                    {
                        self = .comAtprotoAdminDefsRepoBlobRef(updatedValue)
                    }
                }
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }

    public enum ComAtprotoAdminUpdateSubjectStatusSubjectUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, PendingDataLoadable, Equatable {
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

        public static func == (lhs: ComAtprotoAdminUpdateSubjectStatusSubjectUnion, rhs: ComAtprotoAdminUpdateSubjectStatusSubjectUnion) -> Bool {
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
            guard let otherValue = other as? ComAtprotoAdminUpdateSubjectStatusSubjectUnion else { return false }
            return self == otherValue
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
                // Handle nested PendingDataLoadable values
                if let loadableValue = value as? PendingDataLoadable, loadableValue.hasPendingData {
                    // Create a mutable copy we can work with
                    var mutableLoadable = loadableValue
                    await mutableLoadable.loadPendingData()

                    // Only try to cast back if the original value was of the expected type
                    if let originalValue = value as? ComAtprotoAdminDefs.RepoRef,
                       let updatedValue = mutableLoadable as? ComAtprotoAdminDefs.RepoRef
                    {
                        self = .comAtprotoAdminDefsRepoRef(updatedValue)
                    }
                }
            case let .comAtprotoRepoStrongRef(value):
                // Handle nested PendingDataLoadable values
                if let loadableValue = value as? PendingDataLoadable, loadableValue.hasPendingData {
                    // Create a mutable copy we can work with
                    var mutableLoadable = loadableValue
                    await mutableLoadable.loadPendingData()

                    // Only try to cast back if the original value was of the expected type
                    if let originalValue = value as? ComAtprotoRepoStrongRef,
                       let updatedValue = mutableLoadable as? ComAtprotoRepoStrongRef
                    {
                        self = .comAtprotoRepoStrongRef(updatedValue)
                    }
                }
            case let .comAtprotoAdminDefsRepoBlobRef(value):
                // Handle nested PendingDataLoadable values
                if let loadableValue = value as? PendingDataLoadable, loadableValue.hasPendingData {
                    // Create a mutable copy we can work with
                    var mutableLoadable = loadableValue
                    await mutableLoadable.loadPendingData()

                    // Only try to cast back if the original value was of the expected type
                    if let originalValue = value as? ComAtprotoAdminDefs.RepoBlobRef,
                       let updatedValue = mutableLoadable as? ComAtprotoAdminDefs.RepoBlobRef
                    {
                        self = .comAtprotoAdminDefsRepoBlobRef(updatedValue)
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
    /// Update the service-specific admin status of a subject (account, record, or blob).
    func updateSubjectStatus(
        input: ComAtprotoAdminUpdateSubjectStatus.Input

    ) async throws -> (responseCode: Int, data: ComAtprotoAdminUpdateSubjectStatus.Output?) {
        let endpoint = "com.atproto.admin.updateSubjectStatus"

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
        let decodedData = try? decoder.decode(ComAtprotoAdminUpdateSubjectStatus.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
