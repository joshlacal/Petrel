import Foundation



// lexicon: 1, id: app.bsky.notification.updateSeen


public struct AppBskyNotificationUpdateSeen { 

    public static let typeIdentifier = "app.bsky.notification.updateSeen"
public struct Input: ATProtocolCodable {
        public let seenAt: ATProtocolDate

        /// Standard public initializer
        public init(seenAt: ATProtocolDate) {
            self.seenAt = seenAt
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.seenAt = try container.decode(ATProtocolDate.self, forKey: .seenAt)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(seenAt, forKey: .seenAt)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let seenAtValue = try seenAt.toCBORValue()
            map = map.adding(key: "seenAt", value: seenAtValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case seenAt
        }
    }



}

extension ATProtoClient.App.Bsky.Notification {
    // MARK: - updateSeen

    /// Notify server that the requesting account has seen notifications. Requires auth.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: The HTTP response code
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func updateSeen(
        
        input: AppBskyNotificationUpdateSeen.Input
        
    ) async throws -> Int {
        let endpoint = "app.bsky.notification.updateSeen"
        
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
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.notification.updateSeen")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (_, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        
        return responseCode
        
    }
    
}
                           

