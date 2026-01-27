import Foundation

// lexicon: 1, id: blue.catbird.mls.createConvo

public enum BlueCatbirdMlsCreateConvo {
    public static let typeIdentifier = "blue.catbird.mls.createConvo"

    public struct MetadataInput: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "blue.catbird.mls.createConvo#metadataInput"
        public let name: String?
        public let description: String?

        public init(
            name: String?, description: String?
        ) {
            self.name = name
            self.description = description
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                name = try container.decodeIfPresent(String.self, forKey: .name)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'name': \(error)")
                throw error
            }
            do {
                description = try container.decodeIfPresent(String.self, forKey: .description)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'description': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encodeIfPresent(name, forKey: .name)
            try container.encodeIfPresent(description, forKey: .description)
        }

        public func hash(into hasher: inout Hasher) {
            if let value = name {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = description {
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
            if description != other.description {
                return false
            }
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            if let value = name {
                let nameValue = try value.toCBORValue()
                map = map.adding(key: "name", value: nameValue)
            }
            if let value = description {
                let descriptionValue = try value.toCBORValue()
                map = map.adding(key: "description", value: descriptionValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case name
            case description
        }
    }

    public struct KeyPackageHashEntry: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "blue.catbird.mls.createConvo#keyPackageHashEntry"
        public let did: DID
        public let hash: String

        public init(
            did: DID, hash: String
        ) {
            self.did = did
            self.hash = hash
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                did = try container.decode(DID.self, forKey: .did)
            } catch {
                LogManager.logError("Decoding error for required property 'did': \(error)")
                throw error
            }
            do {
                hash = try container.decode(String.self, forKey: .hash)
            } catch {
                LogManager.logError("Decoding error for required property 'hash': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(did, forKey: .did)
            try container.encode(hash, forKey: .hash)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(did)
            hasher.combine(hash)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if did != other.did {
                return false
            }
            if hash != other.hash {
                return false
            }
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)
            let hashValue = try hash.toCBORValue()
            map = map.adding(key: "hash", value: hashValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
            case hash
        }
    }

    public struct Input: ATProtocolCodable {
        public let groupId: String
        public let idempotencyKey: String?
        public let cipherSuite: String
        public let initialMembers: [DID]?
        public let welcomeMessage: String?
        public let keyPackageHashes: [KeyPackageHashEntry]?
        public let metadata: MetadataInput?
        public let currentEpoch: Int?

        /// Standard public initializer
        public init(groupId: String, idempotencyKey: String? = nil, cipherSuite: String, initialMembers: [DID]? = nil, welcomeMessage: String? = nil, keyPackageHashes: [KeyPackageHashEntry]? = nil, metadata: MetadataInput? = nil, currentEpoch: Int? = nil) {
            self.groupId = groupId
            self.idempotencyKey = idempotencyKey
            self.cipherSuite = cipherSuite
            self.initialMembers = initialMembers
            self.welcomeMessage = welcomeMessage
            self.keyPackageHashes = keyPackageHashes
            self.metadata = metadata
            self.currentEpoch = currentEpoch
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            groupId = try container.decode(String.self, forKey: .groupId)
            idempotencyKey = try container.decodeIfPresent(String.self, forKey: .idempotencyKey)
            cipherSuite = try container.decode(String.self, forKey: .cipherSuite)
            initialMembers = try container.decodeIfPresent([DID].self, forKey: .initialMembers)
            welcomeMessage = try container.decodeIfPresent(String.self, forKey: .welcomeMessage)
            keyPackageHashes = try container.decodeIfPresent([KeyPackageHashEntry].self, forKey: .keyPackageHashes)
            metadata = try container.decodeIfPresent(MetadataInput.self, forKey: .metadata)
            currentEpoch = try container.decodeIfPresent(Int.self, forKey: .currentEpoch)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(groupId, forKey: .groupId)
            try container.encodeIfPresent(idempotencyKey, forKey: .idempotencyKey)
            try container.encode(cipherSuite, forKey: .cipherSuite)
            try container.encodeIfPresent(initialMembers, forKey: .initialMembers)
            try container.encodeIfPresent(welcomeMessage, forKey: .welcomeMessage)
            try container.encodeIfPresent(keyPackageHashes, forKey: .keyPackageHashes)
            try container.encodeIfPresent(metadata, forKey: .metadata)
            try container.encodeIfPresent(currentEpoch, forKey: .currentEpoch)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let groupIdValue = try groupId.toCBORValue()
            map = map.adding(key: "groupId", value: groupIdValue)
            if let value = idempotencyKey {
                let idempotencyKeyValue = try value.toCBORValue()
                map = map.adding(key: "idempotencyKey", value: idempotencyKeyValue)
            }
            let cipherSuiteValue = try cipherSuite.toCBORValue()
            map = map.adding(key: "cipherSuite", value: cipherSuiteValue)
            if let value = initialMembers {
                let initialMembersValue = try value.toCBORValue()
                map = map.adding(key: "initialMembers", value: initialMembersValue)
            }
            if let value = welcomeMessage {
                let welcomeMessageValue = try value.toCBORValue()
                map = map.adding(key: "welcomeMessage", value: welcomeMessageValue)
            }
            if let value = keyPackageHashes {
                let keyPackageHashesValue = try value.toCBORValue()
                map = map.adding(key: "keyPackageHashes", value: keyPackageHashesValue)
            }
            if let value = metadata {
                let metadataValue = try value.toCBORValue()
                map = map.adding(key: "metadata", value: metadataValue)
            }
            if let value = currentEpoch {
                let currentEpochValue = try value.toCBORValue()
                map = map.adding(key: "currentEpoch", value: currentEpochValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case groupId
            case idempotencyKey
            case cipherSuite
            case initialMembers
            case welcomeMessage
            case keyPackageHashes
            case metadata
            case currentEpoch
        }
    }

    public typealias Output = BlueCatbirdMlsDefs.ConvoView

    public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
        case invalidCipherSuite = "InvalidCipherSuite.The specified cipher suite is not supported"
        case keyPackageNotFound = "KeyPackageNotFound.Key package not found for one or more initial members"
        case tooManyMembers = "TooManyMembers.Too many initial members specified (default max 1000 total including creator, configurable per-conversation via policy)"
        case mutualBlockDetected = "MutualBlockDetected.Cannot create conversation with users who have blocked each other on Bluesky"
        public var description: String {
            return rawValue
        }

        public var errorName: String {
            // Extract just the error name from the raw value
            let parts = rawValue.split(separator: ".")
            return String(parts.first ?? "")
        }
    }
}

public extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - createConvo

    /// Create a new MLS conversation with optional initial members and metadata Create a new MLS conversation
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func createConvo(
        input: BlueCatbirdMlsCreateConvo.Input

    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsCreateConvo.Output?) {
        let endpoint = "blue.catbird.mls.createConvo"

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

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.createConvo")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsCreateConvo.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.createConvo: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
