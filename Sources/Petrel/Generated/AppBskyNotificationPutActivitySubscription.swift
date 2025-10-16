import Foundation



// lexicon: 1, id: app.bsky.notification.putActivitySubscription


public struct AppBskyNotificationPutActivitySubscription { 

    public static let typeIdentifier = "app.bsky.notification.putActivitySubscription"
public struct Input: ATProtocolCodable {
            public let subject: DID
            public let activitySubscription: AppBskyNotificationDefs.ActivitySubscription

            // Standard public initializer
            public init(subject: DID, activitySubscription: AppBskyNotificationDefs.ActivitySubscription) {
                self.subject = subject
                self.activitySubscription = activitySubscription
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.subject = try container.decode(DID.self, forKey: .subject)
                
                
                self.activitySubscription = try container.decode(AppBskyNotificationDefs.ActivitySubscription.self, forKey: .activitySubscription)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(subject, forKey: .subject)
                
                
                try container.encode(activitySubscription, forKey: .activitySubscription)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case subject
                case activitySubscription
            }
            
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()

                
                
                let subjectValue = try subject.toCBORValue()
                map = map.adding(key: "subject", value: subjectValue)
                
                
                
                let activitySubscriptionValue = try activitySubscription.toCBORValue()
                map = map.adding(key: "activitySubscription", value: activitySubscriptionValue)
                
                

                return map
            }
        }
    
public struct Output: ATProtocolCodable {
        
        
        public let subject: DID
        
        public let activitySubscription: AppBskyNotificationDefs.ActivitySubscription?
        
        
        
        // Standard public initializer
        public init(
            
            
            subject: DID,
            
            activitySubscription: AppBskyNotificationDefs.ActivitySubscription? = nil
            
            
        ) {
            
            
            self.subject = subject
            
            self.activitySubscription = activitySubscription
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.subject = try container.decode(DID.self, forKey: .subject)
            
            
            self.activitySubscription = try container.decodeIfPresent(AppBskyNotificationDefs.ActivitySubscription.self, forKey: .activitySubscription)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(subject, forKey: .subject)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(activitySubscription, forKey: .activitySubscription)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let subjectValue = try subject.toCBORValue()
            map = map.adding(key: "subject", value: subjectValue)
            
            
            
            if let value = activitySubscription {
                // Encode optional property even if it's an empty array for CBOR
                let activitySubscriptionValue = try value.toCBORValue()
                map = map.adding(key: "activitySubscription", value: activitySubscriptionValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case subject
            case activitySubscription
        }
        
    }




}

extension ATProtoClient.App.Bsky.Notification {
    // MARK: - putActivitySubscription

    /// Puts an activity subscription entry. The key should be omitted for creation and provided for updates. Requires auth.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func putActivitySubscription(
        
        input: AppBskyNotificationPutActivitySubscription.Input
        
    ) async throws -> (responseCode: Int, data: AppBskyNotificationPutActivitySubscription.Output?) {
        let endpoint = "app.bsky.notification.putActivitySubscription"
        
        var headers: [String: String] = [:]
        
        headers["Content-Type"] = "application/json"
        
        
        
        headers["Accept"] = "application/json"
        

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.notification.putActivitySubscription")
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
                let decodedData = try decoder.decode(AppBskyNotificationPutActivitySubscription.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.notification.putActivitySubscription: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           
