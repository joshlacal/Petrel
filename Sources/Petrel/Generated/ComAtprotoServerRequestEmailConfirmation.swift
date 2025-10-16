import Foundation



// lexicon: 1, id: com.atproto.server.requestEmailConfirmation


public struct ComAtprotoServerRequestEmailConfirmation { 

    public static let typeIdentifier = "com.atproto.server.requestEmailConfirmation"



}

extension ATProtoClient.Com.Atproto.Server {
    // MARK: - requestEmailConfirmation

    /// Request an email with a code to confirm ownership of email.
    /// 
    /// - Returns: The HTTP response code
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func requestEmailConfirmation(
        
    ) async throws -> Int {
        let endpoint = "com.atproto.server.requestEmailConfirmation"
        
        var headers: [String: String] = [:]
        
        
        

        let requestData: Data? = nil
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "com.atproto.server.requestEmailConfirmation")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (_, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        
        return responseCode
        
    }
    
}
                           
