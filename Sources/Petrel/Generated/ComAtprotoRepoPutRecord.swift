import Foundation



// lexicon: 1, id: com.atproto.repo.putRecord


public struct ComAtprotoRepoPutRecord { 

    public static let typeIdentifier = "com.atproto.repo.putRecord"
public struct Input: ATProtocolCodable {
            public let repo: String
            public let collection: String
            public let rkey: String
            public let validate: Bool?
            public let record: ATProtocolValueContainer
            public let swapRecord: String?
            public let swapCommit: String?

            // Standard public initializer
            public init(repo: String, collection: String, rkey: String, validate: Bool? = nil, record: ATProtocolValueContainer, swapRecord: String? = nil, swapCommit: String? = nil) {
                self.repo = repo
                self.collection = collection
                self.rkey = rkey
                self.validate = validate
                self.record = record
                self.swapRecord = swapRecord
                self.swapCommit = swapCommit
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.repo = try container.decode(String.self, forKey: .repo)
                
                
                self.collection = try container.decode(String.self, forKey: .collection)
                
                
                self.rkey = try container.decode(String.self, forKey: .rkey)
                
                
                self.validate = try container.decodeIfPresent(Bool.self, forKey: .validate)
                
                
                self.record = try container.decode(ATProtocolValueContainer.self, forKey: .record)
                
                
                self.swapRecord = try container.decodeIfPresent(String.self, forKey: .swapRecord)
                
                
                self.swapCommit = try container.decodeIfPresent(String.self, forKey: .swapCommit)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(repo, forKey: .repo)
                
                
                try container.encode(collection, forKey: .collection)
                
                
                try container.encode(rkey, forKey: .rkey)
                
                
                if let value = validate {
                    
                    try container.encode(value, forKey: .validate)
                    
                }
                
                
                try container.encode(record, forKey: .record)
                
                
                if let value = swapRecord {
                    
                    try container.encode(value, forKey: .swapRecord)
                    
                }
                
                
                if let value = swapCommit {
                    
                    try container.encode(value, forKey: .swapCommit)
                    
                }
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case repo
                case collection
                case rkey
                case validate
                case record
                case swapRecord
                case swapCommit
            }
        }
    
public struct Output: ATProtocolCodable {
        
        
        public let uri: ATProtocolURI
        
        public let cid: String
        
        public let commit: ComAtprotoRepoDefs.CommitMeta?
        
        public let validationStatus: String?
        
        
        
        // Standard public initializer
        public init(
            
            uri: ATProtocolURI,
            
            cid: String,
            
            commit: ComAtprotoRepoDefs.CommitMeta? = nil,
            
            validationStatus: String? = nil
            
            
        ) {
            
            self.uri = uri
            
            self.cid = cid
            
            self.commit = commit
            
            self.validationStatus = validationStatus
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.uri = try container.decode(ATProtocolURI.self, forKey: .uri)
            
            
            self.cid = try container.decode(String.self, forKey: .cid)
            
            
            self.commit = try container.decodeIfPresent(ComAtprotoRepoDefs.CommitMeta.self, forKey: .commit)
            
            
            self.validationStatus = try container.decodeIfPresent(String.self, forKey: .validationStatus)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            try container.encode(uri, forKey: .uri)
            
            
            try container.encode(cid, forKey: .cid)
            
            
            if let value = commit {
                
                try container.encode(value, forKey: .commit)
                
            }
            
            
            if let value = validationStatus {
                
                try container.encode(value, forKey: .validationStatus)
                
            }
            
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case uri
            case cid
            case commit
            case validationStatus
            
        }
    }
        
public enum Error: String, Swift.Error, CustomStringConvertible {
                case invalidSwap = "InvalidSwap."
            public var description: String {
                return self.rawValue
            }
        }



}

extension ATProtoClient.Com.Atproto.Repo {
    /// Write a repository record, creating or updating it as needed. Requires auth, implemented by PDS.
    public func putRecord(
        
        input: ComAtprotoRepoPutRecord.Input
        
    ) async throws -> (responseCode: Int, data: ComAtprotoRepoPutRecord.Output?) {
        let endpoint = "com.atproto.repo.putRecord"
        
        var headers: [String: String] = [:]
        
        headers["Content-Type"] = "application/json"
        
        
        
        headers["Accept"] = "application/json"
        
        
        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers, 
            body: requestData,
            queryItems: nil
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
        let decodedData = try? decoder.decode(ComAtprotoRepoPutRecord.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
        
    }
    
}
                           
