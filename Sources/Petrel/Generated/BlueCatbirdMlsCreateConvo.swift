import Foundation



// lexicon: 1, id: blue.catbird.mls.createConvo


public struct BlueCatbirdMlsCreateConvo { 

    public static let typeIdentifier = "blue.catbird.mls.createConvo"
        
public struct MetadataInput: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mls.createConvo#metadataInput"
            public let name: String?
            public let description: String?

        // Standard initializer
        public init(
            name: String?, description: String?
        ) {
            
            self.name = name
            self.description = description
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.name = try container.decodeIfPresent(String.self, forKey: .name)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'name': \(error)")
                
                throw error
            }
            do {
                
                
                self.description = try container.decodeIfPresent(String.self, forKey: .description)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'description': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(name, forKey: .name)
            
            
            
            
            // Encode optional property even if it's an empty array
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            if let value = name {
                // Encode optional property even if it's an empty array for CBOR
                
                let nameValue = try value.toCBORValue()
                map = map.adding(key: "name", value: nameValue)
            }
            
            
            
            
            
            if let value = description {
                // Encode optional property even if it's an empty array for CBOR
                
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

        // Standard initializer
        public init(
            did: DID, hash: String
        ) {
            
            self.did = did
            self.hash = hash
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.did = try container.decode(DID.self, forKey: .did)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'did': \(error)")
                
                throw error
            }
            do {
                
                
                self.hash = try container.decode(String.self, forKey: .hash)
                
                
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
            
            
            if self.did != other.did {
                return false
            }
            
            
            
            
            if self.hash != other.hash {
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

            // Standard public initializer
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
                
                self.groupId = try container.decode(String.self, forKey: .groupId)
                
                
                self.idempotencyKey = try container.decodeIfPresent(String.self, forKey: .idempotencyKey)
                
                
                self.cipherSuite = try container.decode(String.self, forKey: .cipherSuite)
                
                
                self.initialMembers = try container.decodeIfPresent([DID].self, forKey: .initialMembers)
                
                
                self.welcomeMessage = try container.decodeIfPresent(String.self, forKey: .welcomeMessage)
                
                
                self.keyPackageHashes = try container.decodeIfPresent([KeyPackageHashEntry].self, forKey: .keyPackageHashes)
                
                
                self.metadata = try container.decodeIfPresent(MetadataInput.self, forKey: .metadata)
                
                
                self.currentEpoch = try container.decodeIfPresent(Int.self, forKey: .currentEpoch)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(groupId, forKey: .groupId)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(idempotencyKey, forKey: .idempotencyKey)
                
                
                try container.encode(cipherSuite, forKey: .cipherSuite)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(initialMembers, forKey: .initialMembers)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(welcomeMessage, forKey: .welcomeMessage)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(keyPackageHashes, forKey: .keyPackageHashes)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(metadata, forKey: .metadata)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(currentEpoch, forKey: .currentEpoch)
                
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
            
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()

                
                
                let groupIdValue = try groupId.toCBORValue()
                map = map.adding(key: "groupId", value: groupIdValue)
                
                
                
                if let value = idempotencyKey {
                    // Encode optional property even if it's an empty array for CBOR
                    let idempotencyKeyValue = try value.toCBORValue()
                    map = map.adding(key: "idempotencyKey", value: idempotencyKeyValue)
                }
                
                
                
                let cipherSuiteValue = try cipherSuite.toCBORValue()
                map = map.adding(key: "cipherSuite", value: cipherSuiteValue)
                
                
                
                if let value = initialMembers {
                    // Encode optional property even if it's an empty array for CBOR
                    let initialMembersValue = try value.toCBORValue()
                    map = map.adding(key: "initialMembers", value: initialMembersValue)
                }
                
                
                
                if let value = welcomeMessage {
                    // Encode optional property even if it's an empty array for CBOR
                    let welcomeMessageValue = try value.toCBORValue()
                    map = map.adding(key: "welcomeMessage", value: welcomeMessageValue)
                }
                
                
                
                if let value = keyPackageHashes {
                    // Encode optional property even if it's an empty array for CBOR
                    let keyPackageHashesValue = try value.toCBORValue()
                    map = map.adding(key: "keyPackageHashes", value: keyPackageHashesValue)
                }
                
                
                
                if let value = metadata {
                    // Encode optional property even if it's an empty array for CBOR
                    let metadataValue = try value.toCBORValue()
                    map = map.adding(key: "metadata", value: metadataValue)
                }
                
                
                
                if let value = currentEpoch {
                    // Encode optional property even if it's an empty array for CBOR
                    let currentEpochValue = try value.toCBORValue()
                    map = map.adding(key: "currentEpoch", value: currentEpochValue)
                }
                
                

                return map
            }
        }
    public typealias Output = BlueCatbirdMlsDefs.ConvoView
            
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                /// The specified cipher suite is not supported
                case invalidCipherSuite = "InvalidCipherSuite"
                /// Key package not found for one or more initial members
                case keyPackageNotFound = "KeyPackageNotFound"
                /// Too many initial members specified (max 100)
                case tooManyMembers = "TooManyMembers"
                /// Cannot create conversation with users who have blocked each other on Bluesky
                case mutualBlockDetected = "MutualBlockDetected"
            public var description: String {
                return self.rawValue
            }
        }



}

extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - createConvo

    /// Create a new MLS conversation with optional initial members and metadata Create a new MLS conversation
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func createConvo(
        
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
        if (200...299).contains(responseCode) {
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
            // Try to parse structured error response
            if let atprotoError = ATProtoErrorParser.parse(
                data: responseData,
                statusCode: responseCode,
                errorType: BlueCatbirdMlsCreateConvo.Error.self
            ) {
                throw atprotoError
            }
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
        
    }
    
}
                           

