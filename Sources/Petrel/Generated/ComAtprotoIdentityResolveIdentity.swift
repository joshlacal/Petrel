import Foundation



// lexicon: 1, id: com.atproto.identity.resolveIdentity


public struct ComAtprotoIdentityResolveIdentity { 

    public static let typeIdentifier = "com.atproto.identity.resolveIdentity"    
public struct Parameters: Parametrizable {
        public let identifier: ATIdentifier
        
        public init(
            identifier: ATIdentifier
            ) {
            self.identifier = identifier
            
        }
    }
    public typealias Output = ComAtprotoIdentityDefs.IdentityInfo
            
public enum Error: String, Swift.Error, CustomStringConvertible {
                case handleNotFound = "HandleNotFound.The resolution process confirmed that the handle does not resolve to any DID."
                case didNotFound = "DidNotFound.The DID resolution process confirmed that there is no current DID."
                case didDeactivated = "DidDeactivated.The DID previously existed, but has been deactivated."
            public var description: String {
                return self.rawValue
            }
        }



}


extension ATProtoClient.Com.Atproto.Identity {
    // MARK: - resolveIdentity

    /// Resolves an identity (DID or Handle) to a full identity (DID document and verified handle).
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func resolveIdentity(input: ComAtprotoIdentityResolveIdentity.Parameters) async throws -> (responseCode: Int, data: ComAtprotoIdentityResolveIdentity.Output?) {
        let endpoint = "com.atproto.identity.resolveIdentity"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "com.atproto.identity.resolveIdentity")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        // Only decode response data if request was successful
        if (200...299).contains(responseCode) {
            do {
                
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(ComAtprotoIdentityResolveIdentity.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for com.atproto.identity.resolveIdentity: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}                           

