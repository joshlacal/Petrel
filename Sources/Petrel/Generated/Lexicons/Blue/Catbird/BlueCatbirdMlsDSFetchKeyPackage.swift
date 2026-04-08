import Foundation



// lexicon: 1, id: blue.catbird.mlsDS.fetchKeyPackage


public struct BlueCatbirdMlsDSFetchKeyPackage { 

    public static let typeIdentifier = "blue.catbird.mlsDS.fetchKeyPackage"    
public struct Parameters: Parametrizable {
        public let recipientDid: String
        public let convoId: String
        
        public init(
            recipientDid: String, 
            convoId: String
            ) {
            self.recipientDid = recipientDid
            self.convoId = convoId
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let keyPackage: Bytes
        
        public let keyPackageHash: String
        
        
        
        // Standard public initializer
        public init(
            
            
            keyPackage: Bytes,
            
            keyPackageHash: String
            
            
        ) {
            
            
            self.keyPackage = keyPackage
            
            self.keyPackageHash = keyPackageHash
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.keyPackage = try container.decode(Bytes.self, forKey: .keyPackage)
            
            
            self.keyPackageHash = try container.decode(String.self, forKey: .keyPackageHash)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(keyPackage, forKey: .keyPackage)
            
            
            try container.encode(keyPackageHash, forKey: .keyPackageHash)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let keyPackageValue = try keyPackage.toCBORValue()
            map = map.adding(key: "keyPackage", value: keyPackageValue)
            
            
            
            let keyPackageHashValue = try keyPackageHash.toCBORValue()
            map = map.adding(key: "keyPackageHash", value: keyPackageHashValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case keyPackage
            case keyPackageHash
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case conversationNotFound = "ConversationNotFound."
                case recipientNotFound = "RecipientNotFound."
                case noKeyPackagesAvailable = "NoKeyPackagesAvailable."
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



extension ATProtoClient.Blue.Catbird.MlsDS {
    // MARK: - fetchKeyPackage

    /// Return and consume a key package for a local user, requested by a remote DS. Fetch and atomically consume one key package for a user in the context of a conversation.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func fetchKeyPackage(input: BlueCatbirdMlsDSFetchKeyPackage.Parameters) async throws -> (responseCode: Int, data: BlueCatbirdMlsDSFetchKeyPackage.Output?) {
        let endpoint = "blue.catbird.mlsDS.fetchKeyPackage"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsDS.fetchKeyPackage")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsDSFetchKeyPackage.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsDS.fetchKeyPackage: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

