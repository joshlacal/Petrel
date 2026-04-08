import Foundation



// lexicon: 1, id: place.stream.server.listWebhooks


public struct PlaceStreamServerListWebhooks { 

    public static let typeIdentifier = "place.stream.server.listWebhooks"    
public struct Parameters: Parametrizable {
        public let limit: Int?
        public let cursor: String?
        public let active: Bool?
        public let event: String?
        
        public init(
            limit: Int? = nil, 
            cursor: String? = nil, 
            active: Bool? = nil, 
            event: String? = nil
            ) {
            self.limit = limit
            self.cursor = cursor
            self.active = active
            self.event = event
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let webhooks: [PlaceStreamServerDefs.Webhook]
        
        public let cursor: String?
        
        
        
        // Standard public initializer
        public init(
            
            
            webhooks: [PlaceStreamServerDefs.Webhook],
            
            cursor: String? = nil
            
            
        ) {
            
            
            self.webhooks = webhooks
            
            self.cursor = cursor
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.webhooks = try container.decode([PlaceStreamServerDefs.Webhook].self, forKey: .webhooks)
            
            
            self.cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(webhooks, forKey: .webhooks)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let webhooksValue = try webhooks.toCBORValue()
            map = map.adding(key: "webhooks", value: webhooksValue)
            
            
            
            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR
                let cursorValue = try value.toCBORValue()
                map = map.adding(key: "cursor", value: cursorValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case webhooks
            case cursor
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case invalidCursor = "InvalidCursor.The provided cursor is invalid or expired."
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



extension ATProtoClient.Place.Stream.Server {
    // MARK: - listWebhooks

    /// List webhooks for the authenticated user.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func listWebhooks(input: PlaceStreamServerListWebhooks.Parameters) async throws -> (responseCode: Int, data: PlaceStreamServerListWebhooks.Output?) {
        let endpoint = "place.stream.server.listWebhooks"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "place.stream.server.listWebhooks")
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
                let decodedData = try decoder.decode(PlaceStreamServerListWebhooks.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for place.stream.server.listWebhooks: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

