import Foundation
import ZippyJSON


// lexicon: 1, id: com.atproto.repo.listRecords


public struct ComAtprotoRepoListRecords { 

    public static let typeIdentifier = "com.atproto.repo.listRecords"
        
public struct Record: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "com.atproto.repo.listRecords#record"
            public let uri: ATProtocolURI
            public let cid: String
            public let value: ATProtocolValueContainer

        // Standard initializer
        public init(
            uri: ATProtocolURI, cid: String, value: ATProtocolValueContainer
        ) {
            
            self.uri = uri
            self.cid = cid
            self.value = value
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.uri = try container.decode(ATProtocolURI.self, forKey: .uri)
                
            } catch {
                LogManager.logError("Decoding error for property 'uri': \(error)")
                throw error
            }
            do {
                
                self.cid = try container.decode(String.self, forKey: .cid)
                
            } catch {
                LogManager.logError("Decoding error for property 'cid': \(error)")
                throw error
            }
            do {
                
                self.value = try container.decode(ATProtocolValueContainer.self, forKey: .value)
                
            } catch {
                LogManager.logError("Decoding error for property 'value': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(uri, forKey: .uri)
            
            
            try container.encode(cid, forKey: .cid)
            
            
            try container.encode(value, forKey: .value)
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
            hasher.combine(cid)
            hasher.combine(value)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            
            if self.uri != other.uri {
                return false
            }
            
            
            if self.cid != other.cid {
                return false
            }
            
            
            if self.value != other.value {
                return false
            }
            
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
            case cid
            case value
        }
    }    
public struct Parameters: Parametrizable {
        public let repo: String
        public let collection: String
        public let limit: Int?
        public let cursor: String?
        public let rkeyStart: String?
        public let rkeyEnd: String?
        public let reverse: Bool?
        
        public init(
            repo: String, 
            collection: String, 
            limit: Int? = nil, 
            cursor: String? = nil, 
            rkeyStart: String? = nil, 
            rkeyEnd: String? = nil, 
            reverse: Bool? = nil
            ) {
            self.repo = repo
            self.collection = collection
            self.limit = limit
            self.cursor = cursor
            self.rkeyStart = rkeyStart
            self.rkeyEnd = rkeyEnd
            self.reverse = reverse
            
        }
    }    
    
public struct Output: ATProtocolCodable {
        
        
        public let cursor: String?
        
        public let records: [Record]
        
        
        
        // Standard public initializer
        public init(
            
            cursor: String? = nil,
            
            records: [Record]
            
            
        ) {
            
            self.cursor = cursor
            
            self.records = records
            
            
        }
    }




}


extension ATProtoClient.Com.Atproto.Repo {
    /// List a range of records in a repository, matching a specific collection. Does not require auth.
    public func listRecords(input: ComAtprotoRepoListRecords.Parameters) async throws -> (responseCode: Int, data: ComAtprotoRepoListRecords.Output?) {
        let endpoint = "com.atproto.repo.listRecords"
        
        
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
        
        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(ComAtprotoRepoListRecords.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
