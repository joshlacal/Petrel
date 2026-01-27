import Foundation



// lexicon: 1, id: com.atproto.admin.getAccountInfos


public struct ComAtprotoAdminGetAccountInfos { 

    public static let typeIdentifier = "com.atproto.admin.getAccountInfos"    
public struct Parameters: Parametrizable {
        public let dids: [DID]
        
        public init(
            dids: [DID]
            ) {
            self.dids = dids
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let infos: [ComAtprotoAdminDefs.AccountView]
        
        
        
        // Standard public initializer
        public init(
            
            
            infos: [ComAtprotoAdminDefs.AccountView]
            
            
        ) {
            
            
            self.infos = infos
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.infos = try container.decode([ComAtprotoAdminDefs.AccountView].self, forKey: .infos)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(infos, forKey: .infos)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let infosValue = try infos.toCBORValue()
            map = map.adding(key: "infos", value: infosValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case infos
        }
        
    }




}



extension ATProtoClient.Com.Atproto.Admin {
    // MARK: - getAccountInfos

    /// Get details about some accounts.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getAccountInfos(input: ComAtprotoAdminGetAccountInfos.Parameters) async throws -> (responseCode: Int, data: ComAtprotoAdminGetAccountInfos.Output?) {
        let endpoint = "com.atproto.admin.getAccountInfos"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "com.atproto.admin.getAccountInfos")
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
                let decodedData = try decoder.decode(ComAtprotoAdminGetAccountInfos.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for com.atproto.admin.getAccountInfos: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

