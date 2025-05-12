import Foundation



// lexicon: 1, id: com.atproto.admin.disableInviteCodes


public struct ComAtprotoAdminDisableInviteCodes { 

    public static let typeIdentifier = "com.atproto.admin.disableInviteCodes"
public struct Input: ATProtocolCodable {
            public let codes: [String]?
            public let accounts: [String]?

            // Standard public initializer
            public init(codes: [String]? = nil, accounts: [String]? = nil) {
                self.codes = codes
                self.accounts = accounts
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.codes = try container.decodeIfPresent([String].self, forKey: .codes)
                
                
                self.accounts = try container.decodeIfPresent([String].self, forKey: .accounts)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(codes, forKey: .codes)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(accounts, forKey: .accounts)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case codes
                case accounts
            }
            
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()

                
                
                if let value = codes {
                    // Encode optional property even if it's an empty array for CBOR
                    let codesValue = try value.toCBORValue()
                    map = map.adding(key: "codes", value: codesValue)
                }
                
                
                
                if let value = accounts {
                    // Encode optional property even if it's an empty array for CBOR
                    let accountsValue = try value.toCBORValue()
                    map = map.adding(key: "accounts", value: accountsValue)
                }
                
                

                return map
            }
        }



}

extension ATProtoClient.Com.Atproto.Admin {
    // MARK: - disableInviteCodes

    /// Disable some set of codes and/or all codes associated with a set of users.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: The HTTP response code
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func disableInviteCodes(
        
        input: ComAtprotoAdminDisableInviteCodes.Input
        
    ) async throws -> Int {
        let endpoint = "com.atproto.admin.disableInviteCodes"
        
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

        
        let (_, response) = try await networkService.performRequest(urlRequest)
        let responseCode = response.statusCode
        return responseCode
        
    }
    
}
                           
