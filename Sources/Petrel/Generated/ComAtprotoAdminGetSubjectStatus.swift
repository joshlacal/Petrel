import Foundation

// lexicon: 1, id: com.atproto.admin.getSubjectStatus

public enum ComAtprotoAdminGetSubjectStatus {
    public static let typeIdentifier = "com.atproto.admin.getSubjectStatus"
    public struct Parameters: Parametrizable {
        public let did: DID?
        public let uri: ATProtocolURI?
        public let blob: CID?

        public init(
            did: DID? = nil,
            uri: ATProtocolURI? = nil,
            blob: CID? = nil
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

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            subject = try container.decode(OutputSubjectUnion.self, forKey: .subject)

            takedown = try container.decodeIfPresent(ComAtprotoAdminDefs.StatusAttr.self, forKey: .takedown)

            deactivated = try container.decodeIfPresent(ComAtprotoAdminDefs.StatusAttr.self, forKey: .deactivated)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(subject, forKey: .subject)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(takedown, forKey: .takedown)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(deactivated, forKey: .deactivated)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let subjectValue = try subject.toCBORValue()
            map = map.adding(key: "subject", value: subjectValue)

            if let value = takedown {
                // Encode optional property even if it's an empty array for CBOR
                let takedownValue = try value.toCBORValue()
                map = map.adding(key: "takedown", value: takedownValue)
            }

            if let value = deactivated {
                // Encode optional property even if it's an empty array for CBOR
                let deactivatedValue = try value.toCBORValue()
                map = map.adding(key: "deactivated", value: deactivatedValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case subject
            case takedown
            case deactivated
        }
    }

    public enum OutputSubjectUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case comAtprotoAdminDefsRepoRef(ComAtprotoAdminDefs.RepoRef)
        case comAtprotoRepoStrongRef(ComAtprotoRepoStrongRef)
        case comAtprotoAdminDefsRepoBlobRef(ComAtprotoAdminDefs.RepoBlobRef)
        case unexpected(ATProtocolValueContainer)

        public init(_ value: ComAtprotoAdminDefs.RepoRef) {
            self = .comAtprotoAdminDefsRepoRef(value)
        }

        public init(_ value: ComAtprotoRepoStrongRef) {
            self = .comAtprotoRepoStrongRef(value)
        }

        public init(_ value: ComAtprotoAdminDefs.RepoBlobRef) {
            self = .comAtprotoAdminDefsRepoBlobRef(value)
        }

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
            guard let other = other as? OutputSubjectUnion else { return false }
            return self == other
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .comAtprotoAdminDefsRepoRef(value):
                map = map.adding(key: "$type", value: "com.atproto.admin.defs#repoRef")

                let valueDict = try value.toCBORValue()

                // If the value is already an OrderedCBORMap, merge its entries
                if let orderedMap = valueDict as? OrderedCBORMap {
                    for (key, value) in orderedMap.entries where key != "$type" {
                        map = map.adding(key: key, value: value)
                    }
                } else if let dict = valueDict as? [String: Any] {
                    // Otherwise add each key-value pair from the dictionary
                    for (key, value) in dict where key != "$type" {
                        map = map.adding(key: key, value: value)
                    }
                }
                return map
            case let .comAtprotoRepoStrongRef(value):
                map = map.adding(key: "$type", value: "com.atproto.repo.strongRef")

                let valueDict = try value.toCBORValue()

                // If the value is already an OrderedCBORMap, merge its entries
                if let orderedMap = valueDict as? OrderedCBORMap {
                    for (key, value) in orderedMap.entries where key != "$type" {
                        map = map.adding(key: key, value: value)
                    }
                } else if let dict = valueDict as? [String: Any] {
                    // Otherwise add each key-value pair from the dictionary
                    for (key, value) in dict where key != "$type" {
                        map = map.adding(key: key, value: value)
                    }
                }
                return map
            case let .comAtprotoAdminDefsRepoBlobRef(value):
                map = map.adding(key: "$type", value: "com.atproto.admin.defs#repoBlobRef")

                let valueDict = try value.toCBORValue()

                // If the value is already an OrderedCBORMap, merge its entries
                if let orderedMap = valueDict as? OrderedCBORMap {
                    for (key, value) in orderedMap.entries where key != "$type" {
                        map = map.adding(key: key, value: value)
                    }
                } else if let dict = valueDict as? [String: Any] {
                    // Otherwise add each key-value pair from the dictionary
                    for (key, value) in dict where key != "$type" {
                        map = map.adding(key: key, value: value)
                    }
                }
                return map
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .comAtprotoAdminDefsRepoRef(value):
                return value.hasPendingData
            case let .comAtprotoRepoStrongRef(value):
                return value.hasPendingData
            case let .comAtprotoAdminDefsRepoBlobRef(value):
                return value.hasPendingData
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .comAtprotoAdminDefsRepoRef(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .comAtprotoAdminDefsRepoRef(value)
            case var .comAtprotoRepoStrongRef(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .comAtprotoRepoStrongRef(value)
            case var .comAtprotoAdminDefsRepoBlobRef(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .comAtprotoAdminDefsRepoBlobRef(value)
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }
}

public extension ATProtoClient.Com.Atproto.Admin {
    // MARK: - getSubjectStatus

    /// Get the service-specific admin status of a subject (account, record, or blob).
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getSubjectStatus(input: ComAtprotoAdminGetSubjectStatus.Parameters) async throws -> (responseCode: Int, data: ComAtprotoAdminGetSubjectStatus.Output?) {
        let endpoint = "com.atproto.admin.getSubjectStatus"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkService.performRequest(urlRequest)

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
                let decodedData = try decoder.decode(ComAtprotoAdminGetSubjectStatus.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for com.atproto.admin.getSubjectStatus: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
