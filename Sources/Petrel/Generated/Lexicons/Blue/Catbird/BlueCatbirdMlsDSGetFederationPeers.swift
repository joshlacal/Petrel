import Foundation



// lexicon: 1, id: blue.catbird.mlsDS.getFederationPeers


public struct BlueCatbirdMlsDSGetFederationPeers { 

    public static let typeIdentifier = "blue.catbird.mlsDS.getFederationPeers"
        
public struct PeerRecord: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsDS.getFederationPeers#peerRecord"
            public let dsDid: String
            public let status: String
            public let trustScore: Int?
            public let maxRequestsPerMinute: Int?
            public let note: String?
            public let invalidTokenCount: Int?
            public let rejectedRequestCount: Int?
            public let successfulRequestCount: Int?
            public let lastSeenAt: ATProtocolDate?
            public let createdAt: ATProtocolDate?
            public let updatedAt: ATProtocolDate?

        public init(
            dsDid: String, status: String, trustScore: Int?, maxRequestsPerMinute: Int?, note: String?, invalidTokenCount: Int?, rejectedRequestCount: Int?, successfulRequestCount: Int?, lastSeenAt: ATProtocolDate?, createdAt: ATProtocolDate?, updatedAt: ATProtocolDate?
        ) {
            self.dsDid = dsDid
            self.status = status
            self.trustScore = trustScore
            self.maxRequestsPerMinute = maxRequestsPerMinute
            self.note = note
            self.invalidTokenCount = invalidTokenCount
            self.rejectedRequestCount = rejectedRequestCount
            self.successfulRequestCount = successfulRequestCount
            self.lastSeenAt = lastSeenAt
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.dsDid = try container.decode(String.self, forKey: .dsDid)
            } catch {
                LogManager.logError("Decoding error for required property 'dsDid': \(error)")
                throw error
            }
            do {
                self.status = try container.decode(String.self, forKey: .status)
            } catch {
                LogManager.logError("Decoding error for required property 'status': \(error)")
                throw error
            }
            do {
                self.trustScore = try container.decodeIfPresent(Int.self, forKey: .trustScore)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'trustScore': \(error)")
                throw error
            }
            do {
                self.maxRequestsPerMinute = try container.decodeIfPresent(Int.self, forKey: .maxRequestsPerMinute)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'maxRequestsPerMinute': \(error)")
                throw error
            }
            do {
                self.note = try container.decodeIfPresent(String.self, forKey: .note)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'note': \(error)")
                throw error
            }
            do {
                self.invalidTokenCount = try container.decodeIfPresent(Int.self, forKey: .invalidTokenCount)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'invalidTokenCount': \(error)")
                throw error
            }
            do {
                self.rejectedRequestCount = try container.decodeIfPresent(Int.self, forKey: .rejectedRequestCount)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'rejectedRequestCount': \(error)")
                throw error
            }
            do {
                self.successfulRequestCount = try container.decodeIfPresent(Int.self, forKey: .successfulRequestCount)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'successfulRequestCount': \(error)")
                throw error
            }
            do {
                self.lastSeenAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .lastSeenAt)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'lastSeenAt': \(error)")
                throw error
            }
            do {
                self.createdAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .createdAt)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'createdAt': \(error)")
                throw error
            }
            do {
                self.updatedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .updatedAt)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'updatedAt': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(dsDid, forKey: .dsDid)
            try container.encode(status, forKey: .status)
            try container.encodeIfPresent(trustScore, forKey: .trustScore)
            try container.encodeIfPresent(maxRequestsPerMinute, forKey: .maxRequestsPerMinute)
            try container.encodeIfPresent(note, forKey: .note)
            try container.encodeIfPresent(invalidTokenCount, forKey: .invalidTokenCount)
            try container.encodeIfPresent(rejectedRequestCount, forKey: .rejectedRequestCount)
            try container.encodeIfPresent(successfulRequestCount, forKey: .successfulRequestCount)
            try container.encodeIfPresent(lastSeenAt, forKey: .lastSeenAt)
            try container.encodeIfPresent(createdAt, forKey: .createdAt)
            try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(dsDid)
            hasher.combine(status)
            if let value = trustScore {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = maxRequestsPerMinute {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = note {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = invalidTokenCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = rejectedRequestCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = successfulRequestCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = lastSeenAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = createdAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = updatedAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if dsDid != other.dsDid {
                return false
            }
            if status != other.status {
                return false
            }
            if trustScore != other.trustScore {
                return false
            }
            if maxRequestsPerMinute != other.maxRequestsPerMinute {
                return false
            }
            if note != other.note {
                return false
            }
            if invalidTokenCount != other.invalidTokenCount {
                return false
            }
            if rejectedRequestCount != other.rejectedRequestCount {
                return false
            }
            if successfulRequestCount != other.successfulRequestCount {
                return false
            }
            if lastSeenAt != other.lastSeenAt {
                return false
            }
            if createdAt != other.createdAt {
                return false
            }
            if updatedAt != other.updatedAt {
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
            let dsDidValue = try dsDid.toCBORValue()
            map = map.adding(key: "dsDid", value: dsDidValue)
            let statusValue = try status.toCBORValue()
            map = map.adding(key: "status", value: statusValue)
            if let value = trustScore {
                let trustScoreValue = try value.toCBORValue()
                map = map.adding(key: "trustScore", value: trustScoreValue)
            }
            if let value = maxRequestsPerMinute {
                let maxRequestsPerMinuteValue = try value.toCBORValue()
                map = map.adding(key: "maxRequestsPerMinute", value: maxRequestsPerMinuteValue)
            }
            if let value = note {
                let noteValue = try value.toCBORValue()
                map = map.adding(key: "note", value: noteValue)
            }
            if let value = invalidTokenCount {
                let invalidTokenCountValue = try value.toCBORValue()
                map = map.adding(key: "invalidTokenCount", value: invalidTokenCountValue)
            }
            if let value = rejectedRequestCount {
                let rejectedRequestCountValue = try value.toCBORValue()
                map = map.adding(key: "rejectedRequestCount", value: rejectedRequestCountValue)
            }
            if let value = successfulRequestCount {
                let successfulRequestCountValue = try value.toCBORValue()
                map = map.adding(key: "successfulRequestCount", value: successfulRequestCountValue)
            }
            if let value = lastSeenAt {
                let lastSeenAtValue = try value.toCBORValue()
                map = map.adding(key: "lastSeenAt", value: lastSeenAtValue)
            }
            if let value = createdAt {
                let createdAtValue = try value.toCBORValue()
                map = map.adding(key: "createdAt", value: createdAtValue)
            }
            if let value = updatedAt {
                let updatedAtValue = try value.toCBORValue()
                map = map.adding(key: "updatedAt", value: updatedAtValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case dsDid
            case status
            case trustScore
            case maxRequestsPerMinute
            case note
            case invalidTokenCount
            case rejectedRequestCount
            case successfulRequestCount
            case lastSeenAt
            case createdAt
            case updatedAt
        }
    }    
public struct Parameters: Parametrizable {
        public let status: String?
        public let limit: Int?
        
        public init(
            status: String? = nil, 
            limit: Int? = nil
            ) {
            self.status = status
            self.limit = limit
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let peers: [PeerRecord]
        
        
        
        // Standard public initializer
        public init(
            
            
            peers: [PeerRecord]
            
            
        ) {
            
            
            self.peers = peers
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.peers = try container.decode([PeerRecord].self, forKey: .peers)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(peers, forKey: .peers)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let peersValue = try peers.toCBORValue()
            map = map.adding(key: "peers", value: peersValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case peers
        }
        
    }




}



extension ATProtoClient.Blue.Catbird.MlsDS {
    // MARK: - getFederationPeers

    /// List federation peer policies (admin only). Return a list of known federation peer DS policies, optionally filtered by status.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getFederationPeers(input: BlueCatbirdMlsDSGetFederationPeers.Parameters) async throws -> (responseCode: Int, data: BlueCatbirdMlsDSGetFederationPeers.Output?) {
        let endpoint = "blue.catbird.mlsDS.getFederationPeers"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsDS.getFederationPeers")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsDSGetFederationPeers.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsDS.getFederationPeers: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

