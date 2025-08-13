import Foundation



// lexicon: 1, id: com.atproto.identity.requestPlcOperationSignature


public struct ComAtprotoIdentityRequestPlcOperationSignature { 

    public static let typeIdentifier = "com.atproto.identity.requestPlcOperationSignature"



}

extension ATProtoClient.Com.Atproto.Identity {
    // MARK: - requestPlcOperationSignature

    /// Request an email with a code to in order to request a signed PLC operation. Requires Auth.
    /// 
    /// - Returns: The HTTP response code
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func requestPlcOperationSignature(
        
    ) async throws -> Int {
        let endpoint = "com.atproto.identity.requestPlcOperationSignature"
        
        var headers: [String: String] = [:]
        
        
        

        let requestData: Data? = nil
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
                           
