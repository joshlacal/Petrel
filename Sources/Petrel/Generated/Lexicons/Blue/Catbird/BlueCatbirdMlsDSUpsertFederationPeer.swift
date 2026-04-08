import Foundation



// lexicon: 1, id: blue.catbird.mlsDS.upsertFederationPeer


public struct BlueCatbirdMlsDSUpsertFederationPeer { 

    public static let typeIdentifier = "blue.catbird.mlsDS.upsertFederationPeer"
public struct Input: ATProtocolCodable {
        public let dsDid: String
        public let status: String
        public let maxRequestsPerMinute: Int?
        public let note: String?

        /// Standard public initializer
        public init(dsDid: String, status: String, maxRequestsPerMinute: Int? = nil, note: String? = nil) {
            self.dsDid = dsDid
            self.status = status
            self.maxRequestsPerMinute = maxRequestsPerMinute
            self.note = note
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.dsDid = try container.decode(String.self, forKey: .dsDid)
            self.status = try container.decode(String.self, forKey: .status)
            self.maxRequestsPerMinute = try container.decodeIfPresent(Int.self, forKey: .maxRequestsPerMinute)
            self.note = try container.decodeIfPresent(String.self, forKey: .note)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(dsDid, forKey: .dsDid)
            try container.encode(status, forKey: .status)
            try container.encodeIfPresent(maxRequestsPerMinute, forKey: .maxRequestsPerMinute)
            try container.encodeIfPresent(note, forKey: .note)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let dsDidValue = try dsDid.toCBORValue()
            map = map.adding(key: "dsDid", value: dsDidValue)
            let statusValue = try status.toCBORValue()
            map = map.adding(key: "status", value: statusValue)
            if let value = maxRequestsPerMinute {
                let maxRequestsPerMinuteValue = try value.toCBORValue()
                map = map.adding(key: "maxRequestsPerMinute", value: maxRequestsPerMinuteValue)
            }
            if let value = note {
                let noteValue = try value.toCBORValue()
                map = map.adding(key: "note", value: noteValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case dsDid
            case status
            case maxRequestsPerMinute
            case note
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let updated: Bool
        
        public let peer: BlueCatbirdMlsDSGetFederationPeers.PeerRecord
        
        
        
        // Standard public initializer
        public init(
            
            
            updated: Bool,
            
            peer: BlueCatbirdMlsDSGetFederationPeers.PeerRecord
            
            
        ) {
            
            
            self.updated = updated
            
            self.peer = peer
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.updated = try container.decode(Bool.self, forKey: .updated)
            
            
            self.peer = try container.decode(BlueCatbirdMlsDSGetFederationPeers.PeerRecord.self, forKey: .peer)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(updated, forKey: .updated)
            
            
            try container.encode(peer, forKey: .peer)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let updatedValue = try updated.toCBORValue()
            map = map.adding(key: "updated", value: updatedValue)
            
            
            
            let peerValue = try peer.toCBORValue()
            map = map.adding(key: "peer", value: peerValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case updated
            case peer
        }
        
    }




}

extension ATProtoClient.Blue.Catbird.MlsDS {
    // MARK: - upsertFederationPeer

    /// Create or update a federation peer policy (admin only). Upsert a federation peer policy record. Requires federation admin privileges.
    /// 
    /// - Parameter input: The input parameters for the request
    
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func upsertFederationPeer(
        
        input: BlueCatbirdMlsDSUpsertFederationPeer.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsDSUpsertFederationPeer.Output?) {
        let endpoint = "blue.catbird.mlsDS.upsertFederationPeer"
        
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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsDS.upsertFederationPeer")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsDSUpsertFederationPeer.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsDS.upsertFederationPeer: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

