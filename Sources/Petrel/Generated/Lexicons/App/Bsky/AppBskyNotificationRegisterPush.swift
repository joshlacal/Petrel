import Foundation



// lexicon: 1, id: app.bsky.notification.registerPush


public struct AppBskyNotificationRegisterPush { 

    public static let typeIdentifier = "app.bsky.notification.registerPush"
public struct Input: ATProtocolCodable {
            public let serviceDid: DID
            public let token: String
            public let platform: String
            public let appId: String
            public let ageRestricted: Bool?

            // Standard public initializer
            public init(serviceDid: DID, token: String, platform: String, appId: String, ageRestricted: Bool? = nil) {
                self.serviceDid = serviceDid
                self.token = token
                self.platform = platform
                self.appId = appId
                self.ageRestricted = ageRestricted
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.serviceDid = try container.decode(DID.self, forKey: .serviceDid)
                
                
                self.token = try container.decode(String.self, forKey: .token)
                
                
                self.platform = try container.decode(String.self, forKey: .platform)
                
                
                self.appId = try container.decode(String.self, forKey: .appId)
                
                
                self.ageRestricted = try container.decodeIfPresent(Bool.self, forKey: .ageRestricted)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(serviceDid, forKey: .serviceDid)
                
                
                try container.encode(token, forKey: .token)
                
                
                try container.encode(platform, forKey: .platform)
                
                
                try container.encode(appId, forKey: .appId)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(ageRestricted, forKey: .ageRestricted)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case serviceDid
                case token
                case platform
                case appId
                case ageRestricted
            }
            
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()

                
                
                let serviceDidValue = try serviceDid.toCBORValue()
                map = map.adding(key: "serviceDid", value: serviceDidValue)
                
                
                
                let tokenValue = try token.toCBORValue()
                map = map.adding(key: "token", value: tokenValue)
                
                
                
                let platformValue = try platform.toCBORValue()
                map = map.adding(key: "platform", value: platformValue)
                
                
                
                let appIdValue = try appId.toCBORValue()
                map = map.adding(key: "appId", value: appIdValue)
                
                
                
                if let value = ageRestricted {
                    // Encode optional property even if it's an empty array for CBOR
                    let ageRestrictedValue = try value.toCBORValue()
                    map = map.adding(key: "ageRestricted", value: ageRestrictedValue)
                }
                
                

                return map
            }
        }



}

extension ATProtoClient.App.Bsky.Notification {
    // MARK: - registerPush

    /// Register to receive push notifications, via a specified service, for the requesting account. Requires auth.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: The HTTP response code
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func registerPush(
        
        input: AppBskyNotificationRegisterPush.Input
        
    ) async throws -> Int {
        let endpoint = "app.bsky.notification.registerPush"
        
        var headers: [String: String] = [:]
        
        headers["Content-Type"] = "application/json"
        
        
        

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.notification.registerPush")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (_, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        
        return responseCode
        
    }
    
}
                           

