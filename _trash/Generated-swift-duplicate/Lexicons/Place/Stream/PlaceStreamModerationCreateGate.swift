import Foundation



// lexicon: 1, id: place.stream.moderation.createGate


public struct PlaceStreamModerationCreateGate { 

    public static let typeIdentifier = "place.stream.moderation.createGate"
public struct Input: ATProtocolCodable {
        public let streamer: DID
        public let messageUri: ATProtocolURI

        /// Standard public initializer
        public init(streamer: DID, messageUri: ATProtocolURI) {
            self.streamer = streamer
            self.messageUri = messageUri
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.streamer = try container.decode(DID.self, forKey: .streamer)
            self.messageUri = try container.decode(ATProtocolURI.self, forKey: .messageUri)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(streamer, forKey: .streamer)
            try container.encode(messageUri, forKey: .messageUri)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let streamerValue = try streamer.toCBORValue()
            map = map.adding(key: "streamer", value: streamerValue)
            let messageUriValue = try messageUri.toCBORValue()
            map = map.adding(key: "messageUri", value: messageUriValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case streamer
            case messageUri
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let uri: ATProtocolURI
        
        public let cid: CID
        
        
        
        // Standard public initializer
        public init(
            
            
            uri: ATProtocolURI,
            
            cid: CID
            
            
        ) {
            
            
            self.uri = uri
            
            self.cid = cid
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.uri = try container.decode(ATProtocolURI.self, forKey: .uri)
            
            
            self.cid = try container.decode(CID.self, forKey: .cid)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(uri, forKey: .uri)
            
            
            try container.encode(cid, forKey: .cid)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let uriValue = try uri.toCBORValue()
            map = map.adding(key: "uri", value: uriValue)
            
            
            
            let cidValue = try cid.toCBORValue()
            map = map.adding(key: "cid", value: cidValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case uri
            case cid
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case unauthorized = "Unauthorized.The request lacks valid authentication credentials."
                case forbidden = "Forbidden.The caller does not have permission to hide messages for this streamer."
                case sessionNotFound = "SessionNotFound.The streamer's OAuth session could not be found or is invalid."
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

extension ATProtoClient.Place.Stream.Moderation {
    // MARK: - createGate

    /// Create a gate (hide message) on behalf of a streamer. Requires 'hide' permission. Creates a place.stream.chat.gate record in the streamer's repository.
    /// 
    /// - Parameter input: The input parameters for the request
    
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func createGate(
        
        input: PlaceStreamModerationCreateGate.Input
        
    ) async throws -> (responseCode: Int, data: PlaceStreamModerationCreateGate.Output?) {
        let endpoint = "place.stream.moderation.createGate"
        
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
        let serviceDID = await networkService.getServiceDID(for: "place.stream.moderation.createGate")
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
                let decodedData = try decoder.decode(PlaceStreamModerationCreateGate.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for place.stream.moderation.createGate: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

