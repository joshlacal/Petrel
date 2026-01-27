import Foundation



// lexicon: 1, id: blue.catbird.mls.syncKeyPackages


public struct BlueCatbirdMlsSyncKeyPackages { 

    public static let typeIdentifier = "blue.catbird.mls.syncKeyPackages"
public struct Input: ATProtocolCodable {
        public let localHashes: [String]
        public let deviceId: String

        /// Standard public initializer
        public init(localHashes: [String], deviceId: String) {
            self.localHashes = localHashes
            self.deviceId = deviceId
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.localHashes = try container.decode([String].self, forKey: .localHashes)
            self.deviceId = try container.decode(String.self, forKey: .deviceId)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(localHashes, forKey: .localHashes)
            try container.encode(deviceId, forKey: .deviceId)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let localHashesValue = try localHashes.toCBORValue()
            map = map.adding(key: "localHashes", value: localHashesValue)
            let deviceIdValue = try deviceId.toCBORValue()
            map = map.adding(key: "deviceId", value: deviceIdValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case localHashes
            case deviceId
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let serverHashes: [String]
        
        public let orphanedCount: Int
        
        public let deletedCount: Int
        
        public let orphanedHashes: [String]?
        
        public let remainingAvailable: Int?
        
        public let deviceId: String
        
        
        
        // Standard public initializer
        public init(
            
            
            serverHashes: [String],
            
            orphanedCount: Int,
            
            deletedCount: Int,
            
            orphanedHashes: [String]? = nil,
            
            remainingAvailable: Int? = nil,
            
            deviceId: String
            
            
        ) {
            
            
            self.serverHashes = serverHashes
            
            self.orphanedCount = orphanedCount
            
            self.deletedCount = deletedCount
            
            self.orphanedHashes = orphanedHashes
            
            self.remainingAvailable = remainingAvailable
            
            self.deviceId = deviceId
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.serverHashes = try container.decode([String].self, forKey: .serverHashes)
            
            
            self.orphanedCount = try container.decode(Int.self, forKey: .orphanedCount)
            
            
            self.deletedCount = try container.decode(Int.self, forKey: .deletedCount)
            
            
            self.orphanedHashes = try container.decodeIfPresent([String].self, forKey: .orphanedHashes)
            
            
            self.remainingAvailable = try container.decodeIfPresent(Int.self, forKey: .remainingAvailable)
            
            
            self.deviceId = try container.decode(String.self, forKey: .deviceId)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(serverHashes, forKey: .serverHashes)
            
            
            try container.encode(orphanedCount, forKey: .orphanedCount)
            
            
            try container.encode(deletedCount, forKey: .deletedCount)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(orphanedHashes, forKey: .orphanedHashes)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(remainingAvailable, forKey: .remainingAvailable)
            
            
            try container.encode(deviceId, forKey: .deviceId)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let serverHashesValue = try serverHashes.toCBORValue()
            map = map.adding(key: "serverHashes", value: serverHashesValue)
            
            
            
            let orphanedCountValue = try orphanedCount.toCBORValue()
            map = map.adding(key: "orphanedCount", value: orphanedCountValue)
            
            
            
            let deletedCountValue = try deletedCount.toCBORValue()
            map = map.adding(key: "deletedCount", value: deletedCountValue)
            
            
            
            if let value = orphanedHashes {
                // Encode optional property even if it's an empty array for CBOR
                let orphanedHashesValue = try value.toCBORValue()
                map = map.adding(key: "orphanedHashes", value: orphanedHashesValue)
            }
            
            
            
            if let value = remainingAvailable {
                // Encode optional property even if it's an empty array for CBOR
                let remainingAvailableValue = try value.toCBORValue()
                map = map.adding(key: "remainingAvailable", value: remainingAvailableValue)
            }
            
            
            
            let deviceIdValue = try deviceId.toCBORValue()
            map = map.adding(key: "deviceId", value: deviceIdValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case serverHashes
            case orphanedCount
            case deletedCount
            case orphanedHashes
            case remainingAvailable
            case deviceId
        }
        
    }




}

extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - syncKeyPackages

    /// Synchronize key packages between client and server to prevent NoMatchingKeyPackage errors. Compares server-side available key packages against client-provided local hashes and deletes orphaned server packages that no longer have corresponding private keys on the device. MULTI-DEVICE: deviceId is REQUIRED - only syncs packages for that specific device to prevent cross-device interference.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func syncKeyPackages(
        
        input: BlueCatbirdMlsSyncKeyPackages.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsSyncKeyPackages.Output?) {
        let endpoint = "blue.catbird.mls.syncKeyPackages"
        
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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.syncKeyPackages")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsSyncKeyPackages.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.syncKeyPackages: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

