import Foundation



// lexicon: 1, id: place.stream.moderation.deletePin


public struct PlaceStreamModerationDeletePin { 

    public static let typeIdentifier = "place.stream.moderation.deletePin"
public struct Input: ATProtocolCodable {
        public let streamer: DID
        public let pinUri: ATProtocolURI

        /// Standard public initializer
        public init(streamer: DID, pinUri: ATProtocolURI) {
            self.streamer = streamer
            self.pinUri = pinUri
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.streamer = try container.decode(DID.self, forKey: .streamer)
            self.pinUri = try container.decode(ATProtocolURI.self, forKey: .pinUri)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(streamer, forKey: .streamer)
            try container.encode(pinUri, forKey: .pinUri)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let streamerValue = try streamer.toCBORValue()
            map = map.adding(key: "streamer", value: streamerValue)
            let pinUriValue = try pinUri.toCBORValue()
            map = map.adding(key: "pinUri", value: pinUriValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case streamer
            case pinUri
        }
    }
    
public struct Output: ATProtocolCodable {
        
        // Empty output - no properties (response is {})
        
        
        // Standard public initializer
        public init(
            
        ) {
            
        }
        
        public init(from decoder: Decoder) throws {
            
            // Empty output - just validate it's an object by trying to get any container
            _ = try decoder.singleValueContainer()
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            // Empty output - encode empty object
            _ = encoder.singleValueContainer()
            
        }

        public func toCBORValue() throws -> Any {
            
            // Empty output - return empty CBOR map
            return OrderedCBORMap()
            
        }
        
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case unauthorized = "Unauthorized.The request lacks valid authentication credentials."
                case forbidden = "Forbidden.The caller does not have permission to unpin messages for this streamer."
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
    // MARK: - deletePin

    /// Unpin a pinned chat message on behalf of a streamer. Requires 'message.pin' permission. Deletes the place.stream.chat.pinnedRecord from the streamer's repo.
    /// 
    /// - Parameter input: The input parameters for the request
    
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func deletePin(
        
        input: PlaceStreamModerationDeletePin.Input
        
    ) async throws -> (responseCode: Int, data: PlaceStreamModerationDeletePin.Output?) {
        let endpoint = "place.stream.moderation.deletePin"
        
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
        let serviceDID = await networkService.getServiceDID(for: "place.stream.moderation.deletePin")
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
                let decodedData = try decoder.decode(PlaceStreamModerationDeletePin.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for place.stream.moderation.deletePin: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

