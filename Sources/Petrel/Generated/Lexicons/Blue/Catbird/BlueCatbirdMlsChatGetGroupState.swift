import Foundation



// lexicon: 1, id: blue.catbird.mlsChat.getGroupState


public struct BlueCatbirdMlsChatGetGroupState { 

    public static let typeIdentifier = "blue.catbird.mlsChat.getGroupState"    
public struct Parameters: Parametrizable {
        public let convoId: String
        public let include: String?
        
        public init(
            convoId: String, 
            include: String? = nil
            ) {
            self.convoId = convoId
            self.include = include
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let epoch: Int?
        
        public let groupInfo: Bytes?
        
        public let welcome: Bytes?
        
        public let expiresAt: ATProtocolDate?
        
        
        
        // Standard public initializer
        public init(
            
            
            epoch: Int? = nil,
            
            groupInfo: Bytes? = nil,
            
            welcome: Bytes? = nil,
            
            expiresAt: ATProtocolDate? = nil
            
            
        ) {
            
            
            self.epoch = epoch
            
            self.groupInfo = groupInfo
            
            self.welcome = welcome
            
            self.expiresAt = expiresAt
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.epoch = try container.decodeIfPresent(Int.self, forKey: .epoch)
            
            
            self.groupInfo = try container.decodeIfPresent(Bytes.self, forKey: .groupInfo)
            
            
            self.welcome = try container.decodeIfPresent(Bytes.self, forKey: .welcome)
            
            
            self.expiresAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .expiresAt)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(epoch, forKey: .epoch)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(groupInfo, forKey: .groupInfo)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(welcome, forKey: .welcome)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(expiresAt, forKey: .expiresAt)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            if let value = epoch {
                // Encode optional property even if it's an empty array for CBOR
                let epochValue = try value.toCBORValue()
                map = map.adding(key: "epoch", value: epochValue)
            }
            
            
            
            if let value = groupInfo {
                // Encode optional property even if it's an empty array for CBOR
                let groupInfoValue = try value.toCBORValue()
                map = map.adding(key: "groupInfo", value: groupInfoValue)
            }
            
            
            
            if let value = welcome {
                // Encode optional property even if it's an empty array for CBOR
                let welcomeValue = try value.toCBORValue()
                map = map.adding(key: "welcome", value: welcomeValue)
            }
            
            
            
            if let value = expiresAt {
                // Encode optional property even if it's an empty array for CBOR
                let expiresAtValue = try value.toCBORValue()
                map = map.adding(key: "expiresAt", value: expiresAtValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case epoch
            case groupInfo
            case welcome
            case expiresAt
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case notFound = "NotFound.Conversation not found"
                case unauthorized = "Unauthorized.Authentication required"
                case groupInfoUnavailable = "GroupInfoUnavailable.Group info is not currently available for this conversation"
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
    // MARK: - getGroupState

    /// Get the current MLS group state for a conversation, including epoch and group info
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getGroupState(input: BlueCatbirdMlsChatGetGroupState.Parameters) async throws -> (responseCode: Int, data: BlueCatbirdMlsChatGetGroupState.Output?) {
        let endpoint = "blue.catbird.mlsChat.getGroupState"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsChat.getGroupState")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsChatGetGroupState.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsChat.getGroupState: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

