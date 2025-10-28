import Foundation



// lexicon: 1, id: com.atproto.identity.updateHandle


public struct ComAtprotoIdentityUpdateHandle { 

    public static let typeIdentifier = "com.atproto.identity.updateHandle"
public struct Input: ATProtocolCodable {
            public let handle: Handle

            // Standard public initializer
            public init(handle: Handle) {
                self.handle = handle
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.handle = try container.decode(Handle.self, forKey: .handle)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(handle, forKey: .handle)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case handle
            }
            
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()

                
                
                let handleValue = try handle.toCBORValue()
                map = map.adding(key: "handle", value: handleValue)
                
                

                return map
            }
        }



}

extension ATProtoClient.Com.Atproto.Identity {
    // MARK: - updateHandle

    /// Updates the current account's handle. Verifies handle validity, and updates did:plc document if necessary. Implemented by PDS, and requires auth.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: The HTTP response code
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func updateHandle(
        
        input: ComAtprotoIdentityUpdateHandle.Input
        
    ) async throws -> Int {
        let endpoint = "com.atproto.identity.updateHandle"
        
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
        let serviceDID = await networkService.getServiceDID(for: "com.atproto.identity.updateHandle")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (_, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        
        return responseCode
        
    }
    
}
                           

