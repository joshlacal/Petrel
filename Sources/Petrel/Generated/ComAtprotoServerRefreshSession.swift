import Foundation



// lexicon: 1, id: com.atproto.server.refreshSession


public struct ComAtprotoServerRefreshSession { 

    public static let typeIdentifier = "com.atproto.server.refreshSession"
    
public struct Output: ATProtocolCodable {
        
        
        public let accessJwt: String
        
        public let refreshJwt: String
        
        public let handle: Handle
        
        public let did: DID
        
        public let didDoc: DIDDocument?
        
        public let active: Bool?
        
        public let status: String?
        
        
        
        // Standard public initializer
        public init(
            
            accessJwt: String,
            
            refreshJwt: String,
            
            handle: Handle,
            
            did: DID,
            
            didDoc: DIDDocument? = nil,
            
            active: Bool? = nil,
            
            status: String? = nil
            
            
        ) {
            
            self.accessJwt = accessJwt
            
            self.refreshJwt = refreshJwt
            
            self.handle = handle
            
            self.did = did
            
            self.didDoc = didDoc
            
            self.active = active
            
            self.status = status
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.accessJwt = try container.decode(String.self, forKey: .accessJwt)
            
            
            self.refreshJwt = try container.decode(String.self, forKey: .refreshJwt)
            
            
            self.handle = try container.decode(Handle.self, forKey: .handle)
            
            
            self.did = try container.decode(DID.self, forKey: .did)
            
            
            self.didDoc = try container.decodeIfPresent(DIDDocument.self, forKey: .didDoc)
            
            
            self.active = try container.decodeIfPresent(Bool.self, forKey: .active)
            
            
            self.status = try container.decodeIfPresent(String.self, forKey: .status)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            try container.encode(accessJwt, forKey: .accessJwt)
            
            
            try container.encode(refreshJwt, forKey: .refreshJwt)
            
            
            try container.encode(handle, forKey: .handle)
            
            
            try container.encode(did, forKey: .did)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(didDoc, forKey: .didDoc)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(active, forKey: .active)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(status, forKey: .status)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let accessJwtValue = try accessJwt.toCBORValue()
            map = map.adding(key: "accessJwt", value: accessJwtValue)
            
            
            
            let refreshJwtValue = try refreshJwt.toCBORValue()
            map = map.adding(key: "refreshJwt", value: refreshJwtValue)
            
            
            
            let handleValue = try handle.toCBORValue()
            map = map.adding(key: "handle", value: handleValue)
            
            
            
            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)
            
            
            
            if let value = didDoc {
                // Encode optional property even if it's an empty array for CBOR
                let didDocValue = try value.toCBORValue()
                map = map.adding(key: "didDoc", value: didDocValue)
            }
            
            
            
            if let value = active {
                // Encode optional property even if it's an empty array for CBOR
                let activeValue = try value.toCBORValue()
                map = map.adding(key: "active", value: activeValue)
            }
            
            
            
            if let value = status {
                // Encode optional property even if it's an empty array for CBOR
                let statusValue = try value.toCBORValue()
                map = map.adding(key: "status", value: statusValue)
            }
            
            

            return map
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case accessJwt
            case refreshJwt
            case handle
            case did
            case didDoc
            case active
            case status
            
        }
    }
        
public enum Error: String, Swift.Error, CustomStringConvertible {
                case accountTakedown = "AccountTakedown."
            public var description: String {
                return self.rawValue
            }
        }



}

extension ATProtoClient.Com.Atproto.Server {
    // MARK: - refreshSession

    /// Refresh an authentication session. Requires auth using the 'refreshJwt' (not the 'accessJwt').
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func refreshSession(
        
    ) async throws -> (responseCode: Int, data: ComAtprotoServerRefreshSession.Output?) {
        let endpoint = "com.atproto.server.refreshSession"
        
        var headers: [String: String] = [:]
        
        
        
        headers["Accept"] = "application/json"
        

        let requestData: Data? = nil
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
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
        if (200...299).contains(responseCode) {
            do {
                
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(ComAtprotoServerRefreshSession.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for com.atproto.server.refreshSession: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           
