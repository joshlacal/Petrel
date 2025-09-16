import Foundation



// lexicon: 1, id: com.atproto.admin.searchAccounts


public struct ComAtprotoAdminSearchAccounts { 

    public static let typeIdentifier = "com.atproto.admin.searchAccounts"    
public struct Parameters: Parametrizable {
        public let email: String?
        public let cursor: String?
        public let limit: Int?
        
        public init(
            email: String? = nil, 
            cursor: String? = nil, 
            limit: Int? = nil
            ) {
            self.email = email
            self.cursor = cursor
            self.limit = limit
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let cursor: String?
        
        public let accounts: [ComAtprotoAdminDefs.AccountView]
        
        
        
        // Standard public initializer
        public init(
            
            cursor: String? = nil,
            
            accounts: [ComAtprotoAdminDefs.AccountView]
            
            
        ) {
            
            self.cursor = cursor
            
            self.accounts = accounts
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
            
            
            self.accounts = try container.decode([ComAtprotoAdminDefs.AccountView].self, forKey: .accounts)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)
            
            
            try container.encode(accounts, forKey: .accounts)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR
                let cursorValue = try value.toCBORValue()
                map = map.adding(key: "cursor", value: cursorValue)
            }
            
            
            
            let accountsValue = try accounts.toCBORValue()
            map = map.adding(key: "accounts", value: accountsValue)
            
            

            return map
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case cursor
            case accounts
            
        }
    }




}


extension ATProtoClient.Com.Atproto.Admin {
    // MARK: - searchAccounts

    /// Get list of accounts that matches your search query.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func searchAccounts(input: ComAtprotoAdminSearchAccounts.Parameters) async throws -> (responseCode: Int, data: ComAtprotoAdminSearchAccounts.Output?) {
        let endpoint = "com.atproto.admin.searchAccounts"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        
        let (responseData, response) = try await networkService.performRequest(urlRequest)
        
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
                let decodedData = try decoder.decode(ComAtprotoAdminSearchAccounts.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for com.atproto.admin.searchAccounts: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}                           
