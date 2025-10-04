import Foundation



// lexicon: 1, id: com.atproto.server.createInviteCodes


public struct ComAtprotoServerCreateInviteCodes { 

    public static let typeIdentifier = "com.atproto.server.createInviteCodes"
        
public struct AccountCodes: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "com.atproto.server.createInviteCodes#accountCodes"
            public let account: String
            public let codes: [String]

        // Standard initializer
        public init(
            account: String, codes: [String]
        ) {
            
            self.account = account
            self.codes = codes
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.account = try container.decode(String.self, forKey: .account)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'account': \(error)")
                
                throw error
            }
            do {
                
                
                self.codes = try container.decode([String].self, forKey: .codes)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'codes': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(account, forKey: .account)
            
            
            
            
            try container.encode(codes, forKey: .codes)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(account)
            hasher.combine(codes)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.account != other.account {
                return false
            }
            
            
            
            
            if self.codes != other.codes {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let accountValue = try account.toCBORValue()
            map = map.adding(key: "account", value: accountValue)
            
            
            
            
            
            
            let codesValue = try codes.toCBORValue()
            map = map.adding(key: "codes", value: codesValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case account
            case codes
        }
    }
public struct Input: ATProtocolCodable {
            public let codeCount: Int
            public let useCount: Int
            public let forAccounts: [DID]?

            // Standard public initializer
            public init(codeCount: Int, useCount: Int, forAccounts: [DID]? = nil) {
                self.codeCount = codeCount
                self.useCount = useCount
                self.forAccounts = forAccounts
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.codeCount = try container.decode(Int.self, forKey: .codeCount)
                
                
                self.useCount = try container.decode(Int.self, forKey: .useCount)
                
                
                self.forAccounts = try container.decodeIfPresent([DID].self, forKey: .forAccounts)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(codeCount, forKey: .codeCount)
                
                
                try container.encode(useCount, forKey: .useCount)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(forAccounts, forKey: .forAccounts)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case codeCount
                case useCount
                case forAccounts
            }
            
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()

                
                
                let codeCountValue = try codeCount.toCBORValue()
                map = map.adding(key: "codeCount", value: codeCountValue)
                
                
                
                let useCountValue = try useCount.toCBORValue()
                map = map.adding(key: "useCount", value: useCountValue)
                
                
                
                if let value = forAccounts {
                    // Encode optional property even if it's an empty array for CBOR
                    let forAccountsValue = try value.toCBORValue()
                    map = map.adding(key: "forAccounts", value: forAccountsValue)
                }
                
                

                return map
            }
        }
    
public struct Output: ATProtocolCodable {
        
        
        public let codes: [AccountCodes]
        
        
        
        // Standard public initializer
        public init(
            
            codes: [AccountCodes]
            
            
        ) {
            
            self.codes = codes
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.codes = try container.decode([AccountCodes].self, forKey: .codes)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            try container.encode(codes, forKey: .codes)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let codesValue = try codes.toCBORValue()
            map = map.adding(key: "codes", value: codesValue)
            
            

            return map
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case codes
            
        }
    }




}

extension ATProtoClient.Com.Atproto.Server {
    // MARK: - createInviteCodes

    /// Create invite codes.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func createInviteCodes(
        
        input: ComAtprotoServerCreateInviteCodes.Input
        
    ) async throws -> (responseCode: Int, data: ComAtprotoServerCreateInviteCodes.Output?) {
        let endpoint = "com.atproto.server.createInviteCodes"
        
        var headers: [String: String] = [:]
        
        headers["Content-Type"] = "application/json"
        
        
        
        headers["Accept"] = "application/json"
        

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
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
                let decodedData = try decoder.decode(ComAtprotoServerCreateInviteCodes.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for com.atproto.server.createInviteCodes: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           
