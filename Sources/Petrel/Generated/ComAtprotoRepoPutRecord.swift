import Foundation



// lexicon: 1, id: com.atproto.repo.putRecord


public struct ComAtprotoRepoPutRecord { 

    public static let typeIdentifier = "com.atproto.repo.putRecord"
public struct Input: ATProtocolCodable {
            public let repo: ATIdentifier
            public let collection: NSID
            public let rkey: RecordKey
            public let validate: Bool?
            public let record: ATProtocolValueContainer
            public let swapRecord: CID?
            public let swapCommit: CID?

            // Standard public initializer
            public init(repo: ATIdentifier, collection: NSID, rkey: RecordKey, validate: Bool? = nil, record: ATProtocolValueContainer, swapRecord: CID? = nil, swapCommit: CID? = nil) {
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
                
                self.repo = try container.decode(ATIdentifier.self, forKey: .repo)
                
                
                self.collection = try container.decode(NSID.self, forKey: .collection)
                
                
                self.rkey = try container.decode(RecordKey.self, forKey: .rkey)
                
                
                self.validate = try container.decodeIfPresent(Bool.self, forKey: .validate)
                
                
                self.record = try container.decode(ATProtocolValueContainer.self, forKey: .record)
                
                
                self.swapRecord = try container.decodeIfPresent(CID.self, forKey: .swapRecord)
                
                
                self.swapCommit = try container.decodeIfPresent(CID.self, forKey: .swapCommit)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(repo, forKey: .repo)
                
                
                try container.encode(collection, forKey: .collection)
                
                
                try container.encode(rkey, forKey: .rkey)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(validate, forKey: .validate)
                
                
                try container.encode(record, forKey: .record)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(swapRecord, forKey: .swapRecord)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(swapCommit, forKey: .swapCommit)
                
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
            
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()

                
                
                let repoValue = try repo.toCBORValue()
                map = map.adding(key: "repo", value: repoValue)
                
                
                
                let collectionValue = try collection.toCBORValue()
                map = map.adding(key: "collection", value: collectionValue)
                
                
                
                let rkeyValue = try rkey.toCBORValue()
                map = map.adding(key: "rkey", value: rkeyValue)
                
                
                
                if let value = validate {
                    // Encode optional property even if it's an empty array for CBOR
                    let validateValue = try value.toCBORValue()
                    map = map.adding(key: "validate", value: validateValue)
                }
                
                
                
                let recordValue = try record.toCBORValue()
                map = map.adding(key: "record", value: recordValue)
                
                
                
                if let value = swapRecord {
                    // Encode optional property even if it's an empty array for CBOR
                    let swapRecordValue = try value.toCBORValue()
                    map = map.adding(key: "swapRecord", value: swapRecordValue)
                }
                
                
                
                if let value = swapCommit {
                    // Encode optional property even if it's an empty array for CBOR
                    let swapCommitValue = try value.toCBORValue()
                    map = map.adding(key: "swapCommit", value: swapCommitValue)
                }
                
                

                return map
            }
        }
    
public struct Output: ATProtocolCodable {
        
        
        public let uri: ATProtocolURI
        
        public let cid: CID
        
        public let commit: ComAtprotoRepoDefs.CommitMeta?
        
        public let validationStatus: String?
        
        
        
        // Standard public initializer
        public init(
            
            uri: ATProtocolURI,
            
            cid: CID,
            
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
            
            
            self.cid = try container.decode(CID.self, forKey: .cid)
            
            
            self.commit = try container.decodeIfPresent(ComAtprotoRepoDefs.CommitMeta.self, forKey: .commit)
            
            
            self.validationStatus = try container.decodeIfPresent(String.self, forKey: .validationStatus)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            try container.encode(uri, forKey: .uri)
            
            
            try container.encode(cid, forKey: .cid)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(commit, forKey: .commit)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(validationStatus, forKey: .validationStatus)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let uriValue = try uri.toCBORValue()
            map = map.adding(key: "uri", value: uriValue)
            
            
            
            let cidValue = try cid.toCBORValue()
            map = map.adding(key: "cid", value: cidValue)
            
            
            
            if let value = commit {
                // Encode optional property even if it's an empty array for CBOR
                let commitValue = try value.toCBORValue()
                map = map.adding(key: "commit", value: commitValue)
            }
            
            
            
            if let value = validationStatus {
                // Encode optional property even if it's an empty array for CBOR
                let validationStatusValue = try value.toCBORValue()
                map = map.adding(key: "validationStatus", value: validationStatusValue)
            }
            
            

            return map
            
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
    // MARK: - putRecord

    /// Write a repository record, creating or updating it as needed. Requires auth, implemented by PDS.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func putRecord(
        
        input: ComAtprotoRepoPutRecord.Input
        
    ) async throws -> (responseCode: Int, data: ComAtprotoRepoPutRecord.Output?) {
        let endpoint = "com.atproto.repo.putRecord"
        
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
        let decodedData = try? decoder.decode(ComAtprotoRepoPutRecord.Output.self, from: responseData)
        

        return (responseCode, decodedData)
        
    }
    
}
                           
