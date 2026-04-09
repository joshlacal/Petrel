import Foundation



// lexicon: 1, id: blue.catbird.mls.getEpoch


public struct BlueCatbirdMlsGetEpoch { 

    public static let typeIdentifier = "blue.catbird.mls.getEpoch"    
public struct Parameters: Parametrizable {
        public let convoId: String
        
        public init(
            convoId: String
            ) {
            self.convoId = convoId
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let convoId: String
        
        public let currentEpoch: Int
        
        
        
        // Standard public initializer
        public init(
            
            
            convoId: String,
            
            currentEpoch: Int
            
            
        ) {
            
            
            self.convoId = convoId
            
            self.currentEpoch = currentEpoch
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.convoId = try container.decode(String.self, forKey: .convoId)
            
            
            self.currentEpoch = try container.decode(Int.self, forKey: .currentEpoch)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(convoId, forKey: .convoId)
            
            
            try container.encode(currentEpoch, forKey: .currentEpoch)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            
            
            
            let currentEpochValue = try currentEpoch.toCBORValue()
            map = map.adding(key: "currentEpoch", value: currentEpochValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case convoId
            case currentEpoch
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case convoNotFound = "ConvoNotFound.Conversation not found"
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
    // MARK: - getEpoch

    /// Get the current epoch for an MLS conversation
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getEpoch(input: BlueCatbirdMlsGetEpoch.Parameters) async throws -> (responseCode: Int, data: BlueCatbirdMlsGetEpoch.Output?) {
        let endpoint = "blue.catbird.mls.getEpoch"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.getEpoch")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsGetEpoch.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.getEpoch: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

