import Foundation



// lexicon: 1, id: com.atproto.temp.requestPhoneVerification


public struct ComAtprotoTempRequestPhoneVerification { 

    public static let typeIdentifier = "com.atproto.temp.requestPhoneVerification"
public struct Input: ATProtocolCodable {
            public let phoneNumber: String

            // Standard public initializer
            public init(phoneNumber: String) {
                self.phoneNumber = phoneNumber
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.phoneNumber = try container.decode(String.self, forKey: .phoneNumber)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(phoneNumber, forKey: .phoneNumber)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case phoneNumber
            }
        }



}

extension ATProtoClient.Com.Atproto.Temp {
    /// Request a verification code to be sent to the supplied phone number
    public func requestPhoneVerification(
        
        input: ComAtprotoTempRequestPhoneVerification.Input
        
    ) async throws -> Int {
        let endpoint = "com.atproto.temp.requestPhoneVerification"
        
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
                           
