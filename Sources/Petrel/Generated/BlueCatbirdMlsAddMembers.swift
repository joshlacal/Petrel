import Foundation



// lexicon: 1, id: blue.catbird.mls.addMembers


public struct BlueCatbirdMlsAddMembers { 

    public static let typeIdentifier = "blue.catbird.mls.addMembers"
        
public struct KeyPackageHashEntry: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mls.addMembers#keyPackageHashEntry"
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
            public let convoId: String
            public let idempotencyKey: String?
            public let didList: [DID]
            public let commit: String?
            public let welcomeMessage: String?
            public let keyPackageHashes: [KeyPackageHashEntry]?

            // Standard public initializer
            public init(convoId: String, idempotencyKey: String? = nil, didList: [DID], commit: String? = nil, welcomeMessage: String? = nil, keyPackageHashes: [KeyPackageHashEntry]? = nil) {
                self.convoId = convoId
                self.idempotencyKey = idempotencyKey
                self.didList = didList
                self.commit = commit
                self.welcomeMessage = welcomeMessage
                self.keyPackageHashes = keyPackageHashes
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.convoId = try container.decode(String.self, forKey: .convoId)
                
                
                self.idempotencyKey = try container.decodeIfPresent(String.self, forKey: .idempotencyKey)
                
                
                self.didList = try container.decode([DID].self, forKey: .didList)
                
                
                self.commit = try container.decodeIfPresent(String.self, forKey: .commit)
                
                
                self.welcomeMessage = try container.decodeIfPresent(String.self, forKey: .welcomeMessage)
                
                
                self.keyPackageHashes = try container.decodeIfPresent([KeyPackageHashEntry].self, forKey: .keyPackageHashes)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(convoId, forKey: .convoId)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(idempotencyKey, forKey: .idempotencyKey)
                
                
                try container.encode(didList, forKey: .didList)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(commit, forKey: .commit)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(welcomeMessage, forKey: .welcomeMessage)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(keyPackageHashes, forKey: .keyPackageHashes)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case convoId
                case idempotencyKey
                case didList
                case commit
                case welcomeMessage
                case keyPackageHashes
            }
            
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()

                
                
                let convoIdValue = try convoId.toCBORValue()
                map = map.adding(key: "convoId", value: convoIdValue)
                
                
                
                if let value = idempotencyKey {
                    // Encode optional property even if it's an empty array for CBOR
                    let idempotencyKeyValue = try value.toCBORValue()
                    map = map.adding(key: "idempotencyKey", value: idempotencyKeyValue)
                }
                
                
                
                let didListValue = try didList.toCBORValue()
                map = map.adding(key: "didList", value: didListValue)
                
                
                
                if let value = commit {
                    // Encode optional property even if it's an empty array for CBOR
                    let commitValue = try value.toCBORValue()
                    map = map.adding(key: "commit", value: commitValue)
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
                
                

                return map
            }
        }
    
public struct Output: ATProtocolCodable {
        
        
        public let success: Bool
        
        public let newEpoch: Int
        
        
        
        // Standard public initializer
        public init(
            
            
            success: Bool,
            
            newEpoch: Int
            
            
        ) {
            
            
            self.success = success
            
            self.newEpoch = newEpoch
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.success = try container.decode(Bool.self, forKey: .success)
            
            
            self.newEpoch = try container.decode(Int.self, forKey: .newEpoch)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(success, forKey: .success)
            
            
            try container.encode(newEpoch, forKey: .newEpoch)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let successValue = try success.toCBORValue()
            map = map.adding(key: "success", value: successValue)
            
            
            
            let newEpochValue = try newEpoch.toCBORValue()
            map = map.adding(key: "newEpoch", value: newEpochValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case success
            case newEpoch
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                /// Conversation not found
                case convoNotFound = "ConvoNotFound"
                /// Caller is not a member of the conversation
                case notMember = "NotMember"
                /// Key package not found for one or more members
                case keyPackageNotFound = "KeyPackageNotFound"
                /// One or more DIDs are already members
                case alreadyMember = "AlreadyMember"
                /// Would exceed maximum member count
                case tooManyMembers = "TooManyMembers"
                /// Cannot add user who has blocked or been blocked by an existing member (Bluesky social graph enforcement)
                case blockedByMember = "BlockedByMember"
            public var description: String {
                return self.rawValue
            }
        }



}

extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - addMembers

    /// Add new members to an existing MLS conversation Add members to an existing MLS conversation
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func addMembers(
        
        input: BlueCatbirdMlsAddMembers.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsAddMembers.Output?) {
        let endpoint = "blue.catbird.mls.addMembers"
        
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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.addMembers")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsAddMembers.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.addMembers: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Try to parse structured error response
            if let atprotoError = ATProtoErrorParser.parse(
                data: responseData,
                statusCode: responseCode,
                errorType: BlueCatbirdMlsAddMembers.Error.self
            ) {
                throw atprotoError
            }
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
        
    }
    
}
                           

