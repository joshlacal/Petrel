import Foundation



// lexicon: 1, id: com.atproto.server.deactivateAccount


public struct ComAtprotoServerDeactivateAccount { 

    public static let typeIdentifier = "com.atproto.server.deactivateAccount"
public struct Input: ATProtocolCodable {
            public let deleteAfter: ATProtocolDate?

            // Standard public initializer
            public init(deleteAfter: ATProtocolDate? = nil) {
                self.deleteAfter = deleteAfter
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.deleteAfter = try container.decodeIfPresent(ATProtocolDate.self, forKey: .deleteAfter)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(deleteAfter, forKey: .deleteAfter)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case deleteAfter
            }
            
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()

                
                
                if let value = deleteAfter {
                    // Encode optional property even if it's an empty array for CBOR
                    let deleteAfterValue = try value.toCBORValue()
                    map = map.adding(key: "deleteAfter", value: deleteAfterValue)
                }
                
                

                return map
            }
        }



}

extension ATProtoClient.Com.Atproto.Server {
    // MARK: - deactivateAccount

    /// Deactivates a currently active account. Stops serving of repo, and future writes to repo until reactivated. Used to finalize account migration with the old host after the account has been activated on the new host.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: The HTTP response code
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func deactivateAccount(
        
        input: ComAtprotoServerDeactivateAccount.Input
        
    ) async throws -> Int {
        let endpoint = "com.atproto.server.deactivateAccount"
        
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
        let serviceDID = await networkService.getServiceDID(for: "com.atproto.server.deactivateAccount")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (_, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        
        return responseCode
        
    }
    
}
                           
