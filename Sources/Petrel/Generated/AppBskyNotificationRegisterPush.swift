import Foundation



// lexicon: 1, id: app.bsky.notification.registerPush


public struct AppBskyNotificationRegisterPush { 

    public static let typeIdentifier = "app.bsky.notification.registerPush"
public struct Input: ATProtocolCodable {
            public let serviceDid: DID
            public let token: String
            public let platform: String
            public let appId: String

            // Standard public initializer
            public init(serviceDid: DID, token: String, platform: String, appId: String) {
                self.serviceDid = serviceDid
                self.token = token
                self.platform = platform
                self.appId = appId
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.serviceDid = try container.decode(DID.self, forKey: .serviceDid)
                
                
                self.token = try container.decode(String.self, forKey: .token)
                
                
                self.platform = try container.decode(String.self, forKey: .platform)
                
                
                self.appId = try container.decode(String.self, forKey: .appId)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(serviceDid, forKey: .serviceDid)
                
                
                try container.encode(token, forKey: .token)
                
                
                try container.encode(platform, forKey: .platform)
                
                
                try container.encode(appId, forKey: .appId)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case serviceDid
                case token
                case platform
                case appId
            }
            
            // DAGCBOR encoding with field ordering
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()
                
                // Add fields in lexicon-defined order
                
                
                
                let serviceDidValue = try (serviceDid as? DAGCBOREncodable)?.toCBORValue() ?? serviceDid
                map = map.adding(key: "serviceDid", value: serviceDidValue)
                
                
                
                
                let tokenValue = try (token as? DAGCBOREncodable)?.toCBORValue() ?? token
                map = map.adding(key: "token", value: tokenValue)
                
                
                
                
                let platformValue = try (platform as? DAGCBOREncodable)?.toCBORValue() ?? platform
                map = map.adding(key: "platform", value: platformValue)
                
                
                
                
                let appIdValue = try (appId as? DAGCBOREncodable)?.toCBORValue() ?? appId
                map = map.adding(key: "appId", value: appIdValue)
                
                
                
                return map
            }
        }



}

extension ATProtoClient.App.Bsky.Notification {
    /// Register to receive push notifications, via a specified service, for the requesting account. Requires auth.
    public func registerPush(
        
        input: AppBskyNotificationRegisterPush.Input
        
    ) async throws -> Int {
        let endpoint = "app.bsky.notification.registerPush"
        
        var headers: [String: String] = [:]
        
        headers["Content-Type"] = "application/json"
        
        
        
        
        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers, 
            body: requestData,
            queryItems: nil
        )
        
        
        let (_, response) = try await networkManager.performRequest(urlRequest)
        let responseCode = response.statusCode
        return responseCode
        
    }
    
}
                           
