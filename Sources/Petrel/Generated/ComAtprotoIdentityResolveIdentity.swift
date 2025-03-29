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
    /// Resolves an identity (DID or Handle) to a full identity (DID document and verified handle).
    public func resolveIdentity(input: ComAtprotoIdentityResolveIdentity.Parameters) async throws -> (responseCode: Int, data: ComAtprotoIdentityResolveIdentity.Output?) {
        let endpoint = "com.atproto.identity.resolveIdentity"
        
        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )
        
        let (responseData, response) = try await networkManager.performRequest(urlRequest)
        let responseCode = response.statusCode

        // Content-Type validation
        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }
        
        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        // Data decoding and validation
        
        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(ComAtprotoIdentityResolveIdentity.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
