import Foundation



// lexicon: 1, id: com.atproto.temp.addReservedHandle


public struct ComAtprotoTempAddReservedHandle { 

    public static let typeIdentifier = "com.atproto.temp.addReservedHandle"
public struct Input: ATProtocolCodable {
            public let handle: String

            // Standard public initializer
            public init(handle: String) {
                self.handle = handle
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.handle = try container.decode(String.self, forKey: .handle)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(handle, forKey: .handle)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case handle
            }
            
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()

                
                
                let handleValue = try handle.toCBORValue()
                map = map.adding(key: "handle", value: handleValue)
                
                

                return map
            }
        }
    
public struct Output: ATProtocolCodable {
        
        public let data: Data
        
        
        // Standard public initializer
        public init(
            
            
            data: Data
            
        ) {
            
            
            self.data = data
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            let data = try container.decode(Data.self, forKey: .data)
            self.data = data
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(data, forKey: .data)
            
        }

        public func toCBORValue() throws -> Any {
            
            return data
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case data
            
        }
    }




}

extension ATProtoClient.Com.Atproto.Temp {
    // MARK: - addReservedHandle

    /// Add a handle to the set of reserved handles.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func addReservedHandle(
        
        input: ComAtprotoTempAddReservedHandle.Input
        
    ) async throws -> (responseCode: Int, data: ComAtprotoTempAddReservedHandle.Output?) {
        let endpoint = "com.atproto.temp.addReservedHandle"
        
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

        
        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(ComAtprotoTempAddReservedHandle.Output.self, from: responseData)
        

        return (responseCode, decodedData)
        
    }
    
}
                           
