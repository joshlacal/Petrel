import Foundation



// lexicon: 1, id: blue.catbird.mls.getWelcome


public struct BlueCatbirdMlsGetWelcome { 

    public static let typeIdentifier = "blue.catbird.mls.getWelcome"    
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
        
        public let welcome: String
        
        
        
        // Standard public initializer
        public init(
            
            
            convoId: String,
            
            welcome: String
            
            
        ) {
            
            
            self.convoId = convoId
            
            self.welcome = welcome
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.convoId = try container.decode(String.self, forKey: .convoId)
            
            
            self.welcome = try container.decode(String.self, forKey: .welcome)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(convoId, forKey: .convoId)
            
            
            try container.encode(welcome, forKey: .welcome)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            
            
            
            let welcomeValue = try welcome.toCBORValue()
            map = map.adding(key: "welcome", value: welcomeValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case convoId
            case welcome
        }
        
    }
        
public enum Error: String, Swift.Error, CustomStringConvertible {
                case convoNotFound = "ConvoNotFound.Conversation not found"
                case notMember = "NotMember.Caller is not a member of the conversation"
                case welcomeNotFound = "WelcomeNotFound.No Welcome message available for this user"
            public var description: String {
                return self.rawValue
            }
        }



}


extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - getWelcome

    /// Get Welcome message for joining an MLS conversation Retrieve the Welcome message for a conversation the user is a member of
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getWelcome(input: BlueCatbirdMlsGetWelcome.Parameters) async throws -> (responseCode: Int, data: BlueCatbirdMlsGetWelcome.Output?) {
        let endpoint = "blue.catbird.mls.getWelcome"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.getWelcome")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsGetWelcome.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.getWelcome: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}                           

