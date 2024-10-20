import Foundation
import ZippyJSON


// lexicon: 1, id: com.atproto.sync.requestCrawl


public struct ComAtprotoSyncRequestCrawl { 

    public static let typeIdentifier = "com.atproto.sync.requestCrawl"        
public struct Input: ATProtocolCodable {
            public let hostname: String

            // Standard public initializer
            public init(hostname: String) {
                self.hostname = hostname
                
            }
        }



}

extension ATProtoClient.Com.Atproto.Sync {
    /// Request a service to persistently crawl hosted repos. Expected use is new PDS instances declaring their existence to Relays. Does not require auth.
    public func requestCrawl(
        
        input: ComAtprotoSyncRequestCrawl.Input
        
    ) async throws -> Int {
        let endpoint = "com.atproto.sync.requestCrawl"
        
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
                           
