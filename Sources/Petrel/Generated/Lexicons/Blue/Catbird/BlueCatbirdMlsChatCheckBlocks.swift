import Foundation



// lexicon: 1, id: blue.catbird.mlsChat.checkBlocks


public struct BlueCatbirdMlsChatCheckBlocks { 

    public static let typeIdentifier = "blue.catbird.mlsChat.checkBlocks"
        
public struct BlockRelationship: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.checkBlocks#blockRelationship"
            public let blockerDid: DID
            public let blockedDid: DID
            public let createdAt: ATProtocolDate
            public let blockUri: ATProtocolURI?

        public init(
            blockerDid: DID, blockedDid: DID, createdAt: ATProtocolDate, blockUri: ATProtocolURI?
        ) {
            self.blockerDid = blockerDid
            self.blockedDid = blockedDid
            self.createdAt = createdAt
            self.blockUri = blockUri
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.blockerDid = try container.decode(DID.self, forKey: .blockerDid)
            } catch {
                LogManager.logError("Decoding error for required property 'blockerDid': \(error)")
                throw error
            }
            do {
                self.blockedDid = try container.decode(DID.self, forKey: .blockedDid)
            } catch {
                LogManager.logError("Decoding error for required property 'blockedDid': \(error)")
                throw error
            }
            do {
                self.createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
            } catch {
                LogManager.logError("Decoding error for required property 'createdAt': \(error)")
                throw error
            }
            do {
                self.blockUri = try container.decodeIfPresent(ATProtocolURI.self, forKey: .blockUri)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'blockUri': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(blockerDid, forKey: .blockerDid)
            try container.encode(blockedDid, forKey: .blockedDid)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encodeIfPresent(blockUri, forKey: .blockUri)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(blockerDid)
            hasher.combine(blockedDid)
            hasher.combine(createdAt)
            if let value = blockUri {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if blockerDid != other.blockerDid {
                return false
            }
            if blockedDid != other.blockedDid {
                return false
            }
            if createdAt != other.createdAt {
                return false
            }
            if blockUri != other.blockUri {
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
            let blockerDidValue = try blockerDid.toCBORValue()
            map = map.adding(key: "blockerDid", value: blockerDidValue)
            let blockedDidValue = try blockedDid.toCBORValue()
            map = map.adding(key: "blockedDid", value: blockedDidValue)
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            if let value = blockUri {
                let blockUriValue = try value.toCBORValue()
                map = map.adding(key: "blockUri", value: blockUriValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case blockerDid
            case blockedDid
            case createdAt
            case blockUri
        }
    }
public struct Input: ATProtocolCodable {
        public let dids: [DID]

        /// Standard public initializer
        public init(dids: [DID]) {
            self.dids = dids
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.dids = try container.decode([DID].self, forKey: .dids)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(dids, forKey: .dids)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let didsValue = try dids.toCBORValue()
            map = map.adding(key: "dids", value: didsValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case dids
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let blocked: Bool
        
        public let blocks: [BlockRelationship]
        
        public let checkedAt: ATProtocolDate
        
        
        
        // Standard public initializer
        public init(
            
            
            blocked: Bool,
            
            blocks: [BlockRelationship],
            
            checkedAt: ATProtocolDate
            
            
        ) {
            
            
            self.blocked = blocked
            
            self.blocks = blocks
            
            self.checkedAt = checkedAt
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.blocked = try container.decode(Bool.self, forKey: .blocked)
            
            
            self.blocks = try container.decode([BlockRelationship].self, forKey: .blocks)
            
            
            self.checkedAt = try container.decode(ATProtocolDate.self, forKey: .checkedAt)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(blocked, forKey: .blocked)
            
            
            try container.encode(blocks, forKey: .blocks)
            
            
            try container.encode(checkedAt, forKey: .checkedAt)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let blockedValue = try blocked.toCBORValue()
            map = map.adding(key: "blocked", value: blockedValue)
            
            
            
            let blocksValue = try blocks.toCBORValue()
            map = map.adding(key: "blocks", value: blocksValue)
            
            
            
            let checkedAtValue = try checkedAt.toCBORValue()
            map = map.adding(key: "checkedAt", value: checkedAtValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case blocked
            case blocks
            case checkedAt
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case tooFewDids = "TooFewDids.At least two DIDs are required."
                case tooManyDids = "TooManyDids.Maximum 100 DIDs per request."
                case blueskyServiceUnavailable = "BlueskyServiceUnavailable.Upstream PDS query failed and local cache is empty."
            public var description: String {
                return self.rawValue
            }

            public var errorName: String {
                // Extract just the error name from the raw value
                let parts = self.rawValue.split(separator: ".")
                return String(parts.first ?? "")
            }
        }



}

extension ATProtoClient.Blue.Catbird.MlsChat {
    // MARK: - checkBlocks

    /// Check whether any Bluesky block relationships exist between the given DIDs. Used by clients before creating a group or adding a member to warn the user that a block edge would force auto-leave.
    /// 
    /// - Parameter input: The input parameters for the request
    
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func checkBlocks(
        
        input: BlueCatbirdMlsChatCheckBlocks.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsChatCheckBlocks.Output?) {
        let endpoint = "blue.catbird.mlsChat.checkBlocks"
        
        var headers: [String: String] = [:]
        
        headers["Content-Type"] = "application/json"
        
        
        
        headers["Accept"] = "application/json"
        

        
        let requestData: Data? = try JSONEncoder().encode(input)
        
        
        let queryItems: [URLQueryItem]? = nil
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsChat.checkBlocks")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsChatCheckBlocks.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsChat.checkBlocks: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

