import Foundation



// lexicon: 1, id: blue.catbird.mlsChat.removeDevice


public struct BlueCatbirdMlsChatRemoveDevice { 

    public static let typeIdentifier = "blue.catbird.mlsChat.removeDevice"
public struct Input: ATProtocolCodable {
        public let deviceId: String

        /// Standard public initializer
        public init(deviceId: String) {
            self.deviceId = deviceId
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.deviceId = try container.decode(String.self, forKey: .deviceId)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(deviceId, forKey: .deviceId)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let deviceIdValue = try deviceId.toCBORValue()
            map = map.adding(key: "deviceId", value: deviceIdValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case deviceId
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let deleted: Bool
        
        public let keyPackagesDeleted: Int?
        
        public let conversationsLeft: Int?
        
        
        
        // Standard public initializer
        public init(
            
            
            deleted: Bool,
            
            keyPackagesDeleted: Int? = nil,
            
            conversationsLeft: Int? = nil
            
            
        ) {
            
            
            self.deleted = deleted
            
            self.keyPackagesDeleted = keyPackagesDeleted
            
            self.conversationsLeft = conversationsLeft
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.deleted = try container.decode(Bool.self, forKey: .deleted)
            
            
            self.keyPackagesDeleted = try container.decodeIfPresent(Int.self, forKey: .keyPackagesDeleted)
            
            
            self.conversationsLeft = try container.decodeIfPresent(Int.self, forKey: .conversationsLeft)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(deleted, forKey: .deleted)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(keyPackagesDeleted, forKey: .keyPackagesDeleted)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(conversationsLeft, forKey: .conversationsLeft)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let deletedValue = try deleted.toCBORValue()
            map = map.adding(key: "deleted", value: deletedValue)
            
            
            
            if let value = keyPackagesDeleted {
                // Encode optional property even if it's an empty array for CBOR
                let keyPackagesDeletedValue = try value.toCBORValue()
                map = map.adding(key: "keyPackagesDeleted", value: keyPackagesDeletedValue)
            }
            
            
            
            if let value = conversationsLeft {
                // Encode optional property even if it's an empty array for CBOR
                let conversationsLeftValue = try value.toCBORValue()
                map = map.adding(key: "conversationsLeft", value: conversationsLeftValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case deleted
            case keyPackagesDeleted
            case conversationsLeft
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case deviceNotFound = "DeviceNotFound."
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
    // MARK: - removeDevice

    /// Remove a registered MLS device and clean up associated resources (key packages, conversation memberships, pending welcome messages).
    /// 
    /// - Parameter input: The input parameters for the request
    
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func removeDevice(
        
        input: BlueCatbirdMlsChatRemoveDevice.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsChatRemoveDevice.Output?) {
        let endpoint = "blue.catbird.mlsChat.removeDevice"
        
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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsChat.removeDevice")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsChatRemoveDevice.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsChat.removeDevice: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

