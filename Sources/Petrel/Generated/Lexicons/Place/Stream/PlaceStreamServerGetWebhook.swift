import Foundation



// lexicon: 1, id: place.stream.server.getWebhook


public struct PlaceStreamServerGetWebhook { 

    public static let typeIdentifier = "place.stream.server.getWebhook"    
public struct Parameters: Parametrizable {
        public let id: String
        
        public init(
            id: String
            ) {
            self.id = id
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let webhook: PlaceStreamServerDefs.Webhook
        
        
        
        // Standard public initializer
        public init(
            
            
            webhook: PlaceStreamServerDefs.Webhook
            
            
        ) {
            
            
            self.webhook = webhook
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.webhook = try container.decode(PlaceStreamServerDefs.Webhook.self, forKey: .webhook)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(webhook, forKey: .webhook)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let webhookValue = try webhook.toCBORValue()
            map = map.adding(key: "webhook", value: webhookValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case webhook
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case webhookNotFound = "WebhookNotFound.The specified webhook was not found."
                case unauthorized = "Unauthorized.The authenticated user does not have access to this webhook."
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
    // MARK: - getWebhook

    /// Get details for a specific webhook.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getWebhook(input: PlaceStreamServerGetWebhook.Parameters) async throws -> (responseCode: Int, data: PlaceStreamServerGetWebhook.Output?) {
        let endpoint = "place.stream.server.getWebhook"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "place.stream.server.getWebhook")
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
                let decodedData = try decoder.decode(PlaceStreamServerGetWebhook.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for place.stream.server.getWebhook: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

