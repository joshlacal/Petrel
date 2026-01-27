import Foundation



// lexicon: 1, id: blue.catbird.mls.claimPendingDeviceAddition


public struct BlueCatbirdMlsClaimPendingDeviceAddition { 

    public static let typeIdentifier = "blue.catbird.mls.claimPendingDeviceAddition"
public struct Input: ATProtocolCodable {
            public let pendingAdditionId: String

            // Standard public initializer
            public init(pendingAdditionId: String) {
                self.pendingAdditionId = pendingAdditionId
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.pendingAdditionId = try container.decode(String.self, forKey: .pendingAdditionId)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(pendingAdditionId, forKey: .pendingAdditionId)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case pendingAdditionId
            }
            
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()

                
                
                let pendingAdditionIdValue = try pendingAdditionId.toCBORValue()
                map = map.adding(key: "pendingAdditionId", value: pendingAdditionIdValue)
                
                

                return map
            }
        }
    
public struct Output: ATProtocolCodable {
        
        
        public let claimed: Bool
        
        public let convoId: String?
        
        public let deviceCredentialDid: String?
        
        public let keyPackage: BlueCatbirdMlsDefs.KeyPackageRef?
        
        public let claimedBy: DID?
        
        
        
        // Standard public initializer
        public init(
            
            
            claimed: Bool,
            
            convoId: String? = nil,
            
            deviceCredentialDid: String? = nil,
            
            keyPackage: BlueCatbirdMlsDefs.KeyPackageRef? = nil,
            
            claimedBy: DID? = nil
            
            
        ) {
            
            
            self.claimed = claimed
            
            self.convoId = convoId
            
            self.deviceCredentialDid = deviceCredentialDid
            
            self.keyPackage = keyPackage
            
            self.claimedBy = claimedBy
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.claimed = try container.decode(Bool.self, forKey: .claimed)
            
            
            self.convoId = try container.decodeIfPresent(String.self, forKey: .convoId)
            
            
            self.deviceCredentialDid = try container.decodeIfPresent(String.self, forKey: .deviceCredentialDid)
            
            
            self.keyPackage = try container.decodeIfPresent(BlueCatbirdMlsDefs.KeyPackageRef.self, forKey: .keyPackage)
            
            
            self.claimedBy = try container.decodeIfPresent(DID.self, forKey: .claimedBy)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(claimed, forKey: .claimed)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(convoId, forKey: .convoId)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(deviceCredentialDid, forKey: .deviceCredentialDid)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(keyPackage, forKey: .keyPackage)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(claimedBy, forKey: .claimedBy)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let claimedValue = try claimed.toCBORValue()
            map = map.adding(key: "claimed", value: claimedValue)
            
            
            
            if let value = convoId {
                // Encode optional property even if it's an empty array for CBOR
                let convoIdValue = try value.toCBORValue()
                map = map.adding(key: "convoId", value: convoIdValue)
            }
            
            
            
            if let value = deviceCredentialDid {
                // Encode optional property even if it's an empty array for CBOR
                let deviceCredentialDidValue = try value.toCBORValue()
                map = map.adding(key: "deviceCredentialDid", value: deviceCredentialDidValue)
            }
            
            
            
            if let value = keyPackage {
                // Encode optional property even if it's an empty array for CBOR
                let keyPackageValue = try value.toCBORValue()
                map = map.adding(key: "keyPackage", value: keyPackageValue)
            }
            
            
            
            if let value = claimedBy {
                // Encode optional property even if it's an empty array for CBOR
                let claimedByValue = try value.toCBORValue()
                map = map.adding(key: "claimedBy", value: claimedByValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case claimed
            case convoId
            case deviceCredentialDid
            case keyPackage
            case claimedBy
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case notMember = "NotMember.Caller is not a member of the conversation"
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

extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - claimPendingDeviceAddition

    /// Atomically claim a pending device addition to prevent race conditions Claims a pending device addition so only one member processes it. Claim expires after 60 seconds if not completed. Returns claimed=false with no convoId if pending addition not found or already completed.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func claimPendingDeviceAddition(
        
        input: BlueCatbirdMlsClaimPendingDeviceAddition.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsClaimPendingDeviceAddition.Output?) {
        let endpoint = "blue.catbird.mls.claimPendingDeviceAddition"
        
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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.claimPendingDeviceAddition")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsClaimPendingDeviceAddition.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.claimPendingDeviceAddition: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

