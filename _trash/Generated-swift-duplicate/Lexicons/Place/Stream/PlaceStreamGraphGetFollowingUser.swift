import Foundation



// lexicon: 1, id: place.stream.graph.getFollowingUser


public struct PlaceStreamGraphGetFollowingUser { 

    public static let typeIdentifier = "place.stream.graph.getFollowingUser"    
public struct Parameters: Parametrizable {
        public let userDID: DID
        public let subjectDID: DID
        
        public init(
            userDID: DID, 
            subjectDID: DID
            ) {
            self.userDID = userDID
            self.subjectDID = subjectDID
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let follow: ComAtprotoRepoStrongRef?
        
        
        
        // Standard public initializer
        public init(
            
            
            follow: ComAtprotoRepoStrongRef? = nil
            
            
        ) {
            
            
            self.follow = follow
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.follow = try container.decodeIfPresent(ComAtprotoRepoStrongRef.self, forKey: .follow)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(follow, forKey: .follow)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            if let value = follow {
                // Encode optional property even if it's an empty array for CBOR
                let followValue = try value.toCBORValue()
                map = map.adding(key: "follow", value: followValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case follow
        }
        
    }




}



extension ATProtoClient.Place.Stream.Graph {
    // MARK: - getFollowingUser

    /// Get whether or not user A is following user B.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getFollowingUser(input: PlaceStreamGraphGetFollowingUser.Parameters) async throws -> (responseCode: Int, data: PlaceStreamGraphGetFollowingUser.Output?) {
        let endpoint = "place.stream.graph.getFollowingUser"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "place.stream.graph.getFollowingUser")
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
                let decodedData = try decoder.decode(PlaceStreamGraphGetFollowingUser.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for place.stream.graph.getFollowingUser: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

