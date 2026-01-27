import Foundation



// lexicon: 1, id: blue.catbird.mls.listInvites


public struct BlueCatbirdMlsListInvites { 

    public static let typeIdentifier = "blue.catbird.mls.listInvites"    
public struct Parameters: Parametrizable {
        public let convoId: String
        public let includeRevoked: Bool?
        
        public init(
            convoId: String, 
            includeRevoked: Bool? = nil
            ) {
            self.convoId = convoId
            self.includeRevoked = includeRevoked
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let invites: [BlueCatbirdMlsCreateInvite.InviteView]
        
        
        
        // Standard public initializer
        public init(
            
            
            invites: [BlueCatbirdMlsCreateInvite.InviteView]
            
            
        ) {
            
            
            self.invites = invites
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.invites = try container.decode([BlueCatbirdMlsCreateInvite.InviteView].self, forKey: .invites)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(invites, forKey: .invites)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let invitesValue = try invites.toCBORValue()
            map = map.adding(key: "invites", value: invitesValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case invites
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case unauthorized = "Unauthorized.Caller is not an admin of this conversation"
                case convoNotFound = "ConvoNotFound.Conversation not found"
                case notMember = "NotMember.Caller is not a member of this conversation"
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
    // MARK: - listInvites

    /// List all invite links for a conversation Query to fetch all invites for a conversation. Only admins can list invites.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func listInvites(input: BlueCatbirdMlsListInvites.Parameters) async throws -> (responseCode: Int, data: BlueCatbirdMlsListInvites.Output?) {
        let endpoint = "blue.catbird.mls.listInvites"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.listInvites")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsListInvites.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.listInvites: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

