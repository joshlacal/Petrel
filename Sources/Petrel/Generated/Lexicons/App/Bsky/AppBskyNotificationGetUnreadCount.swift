import Foundation



// lexicon: 1, id: app.bsky.notification.getUnreadCount


public struct AppBskyNotificationGetUnreadCount { 

    public static let typeIdentifier = "app.bsky.notification.getUnreadCount"    
public struct Parameters: Parametrizable {
        public let priority: Bool?
        public let seenAt: ATProtocolDate?
        
        public init(
            priority: Bool? = nil, 
            seenAt: ATProtocolDate? = nil
            ) {
            self.priority = priority
            self.seenAt = seenAt
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let count: Int
        
        
        
        // Standard public initializer
        public init(
            
            
            count: Int
            
            
        ) {
            
            
            self.count = count
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.count = try container.decode(Int.self, forKey: .count)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(count, forKey: .count)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let countValue = try count.toCBORValue()
            map = map.adding(key: "count", value: countValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case count
        }
        
    }




}



extension ATProtoClient.App.Bsky.Notification {
    // MARK: - getUnreadCount

    /// Count the number of unread notifications for the requesting account. Requires auth.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getUnreadCount(input: AppBskyNotificationGetUnreadCount.Parameters) async throws -> (responseCode: Int, data: AppBskyNotificationGetUnreadCount.Output?) {
        let endpoint = "app.bsky.notification.getUnreadCount"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.notification.getUnreadCount")
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
                let decodedData = try decoder.decode(AppBskyNotificationGetUnreadCount.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.notification.getUnreadCount: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

