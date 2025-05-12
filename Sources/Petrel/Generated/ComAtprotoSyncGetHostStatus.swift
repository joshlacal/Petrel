import Foundation



// lexicon: 1, id: com.atproto.sync.getHostStatus


public struct ComAtprotoSyncGetHostStatus { 

    public static let typeIdentifier = "com.atproto.sync.getHostStatus"    
public struct Parameters: Parametrizable {
        public let hostname: String
        
        public init(
            hostname: String
            ) {
            self.hostname = hostname
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let hostname: String
        
        public let seq: Int?
        
        public let accountCount: Int?
        
        public let status: ComAtprotoSyncDefs.HostStatus?
        
        
        
        // Standard public initializer
        public init(
            
            hostname: String,
            
            seq: Int? = nil,
            
            accountCount: Int? = nil,
            
            status: ComAtprotoSyncDefs.HostStatus? = nil
            
            
        ) {
            
            self.hostname = hostname
            
            self.seq = seq
            
            self.accountCount = accountCount
            
            self.status = status
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.hostname = try container.decode(String.self, forKey: .hostname)
            
            
            self.seq = try container.decodeIfPresent(Int.self, forKey: .seq)
            
            
            self.accountCount = try container.decodeIfPresent(Int.self, forKey: .accountCount)
            
            
            self.status = try container.decodeIfPresent(ComAtprotoSyncDefs.HostStatus.self, forKey: .status)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            try container.encode(hostname, forKey: .hostname)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(seq, forKey: .seq)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(accountCount, forKey: .accountCount)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(status, forKey: .status)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let hostnameValue = try hostname.toCBORValue()
            map = map.adding(key: "hostname", value: hostnameValue)
            
            
            
            if let value = seq {
                // Encode optional property even if it's an empty array for CBOR
                let seqValue = try value.toCBORValue()
                map = map.adding(key: "seq", value: seqValue)
            }
            
            
            
            if let value = accountCount {
                // Encode optional property even if it's an empty array for CBOR
                let accountCountValue = try value.toCBORValue()
                map = map.adding(key: "accountCount", value: accountCountValue)
            }
            
            
            
            if let value = status {
                // Encode optional property even if it's an empty array for CBOR
                let statusValue = try value.toCBORValue()
                map = map.adding(key: "status", value: statusValue)
            }
            
            

            return map
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case hostname
            case seq
            case accountCount
            case status
            
        }
    }
        
public enum Error: String, Swift.Error, CustomStringConvertible {
                case hostNotFound = "HostNotFound."
            public var description: String {
                return self.rawValue
            }
        }



}


extension ATProtoClient.Com.Atproto.Sync {
    // MARK: - getHostStatus

    /// Returns information about a specified upstream host, as consumed by the server. Implemented by relays.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getHostStatus(input: ComAtprotoSyncGetHostStatus.Parameters) async throws -> (responseCode: Int, data: ComAtprotoSyncGetHostStatus.Output?) {
        let endpoint = "com.atproto.sync.getHostStatus"

        
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

        
        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(ComAtprotoSyncGetHostStatus.Output.self, from: responseData)
        

        return (responseCode, decodedData)
    }
}                           
