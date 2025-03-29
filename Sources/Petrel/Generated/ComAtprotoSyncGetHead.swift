import Foundation



// lexicon: 1, id: com.atproto.sync.getHead


public struct ComAtprotoSyncGetHead { 

    public static let typeIdentifier = "com.atproto.sync.getHead"    
public struct Parameters: Parametrizable {
        public let did: DID
        
        public init(
            did: DID
            ) {
            self.did = did
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let root: CID
        
        
        
        // Standard public initializer
        public init(
            
            root: CID
            
            
        ) {
            
            self.root = root
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.root = try container.decode(CID.self, forKey: .root)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            try container.encode(root, forKey: .root)
            
            
        }
        
        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()
            
            // Add fields in lexicon-defined order
            
            
            
            let rootValue = try (root as? DAGCBOREncodable)?.toCBORValue() ?? root
            map = map.adding(key: "root", value: rootValue)
            
            
            
            return map
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case root
            
        }
    }
        
public enum Error: String, Swift.Error, CustomStringConvertible {
                case headNotFound = "HeadNotFound."
            public var description: String {
                return self.rawValue
            }
        }



}


extension ATProtoClient.Com.Atproto.Sync {
    /// DEPRECATED - please use com.atproto.sync.getLatestCommit instead
    public func getHead(input: ComAtprotoSyncGetHead.Parameters) async throws -> (responseCode: Int, data: ComAtprotoSyncGetHead.Output?) {
        let endpoint = "com.atproto.sync.getHead"
        
        
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
        let decodedData = try? decoder.decode(ComAtprotoSyncGetHead.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
