import Foundation



// lexicon: 1, id: blue.catbird.mls.leaveConvo


public struct BlueCatbirdMlsLeaveConvo { 

    public static let typeIdentifier = "blue.catbird.mls.leaveConvo"
public struct Input: ATProtocolCodable {
            public let convoId: String
            public let targetDid: DID?
            public let commit: String?

            // Standard public initializer
            public init(convoId: String, targetDid: DID? = nil, commit: String? = nil) {
                self.convoId = convoId
                self.targetDid = targetDid
                self.commit = commit
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.convoId = try container.decode(String.self, forKey: .convoId)
                
                
                self.targetDid = try container.decodeIfPresent(DID.self, forKey: .targetDid)
                
                
                self.commit = try container.decodeIfPresent(String.self, forKey: .commit)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(convoId, forKey: .convoId)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(targetDid, forKey: .targetDid)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(commit, forKey: .commit)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case convoId
                case targetDid
                case commit
            }
            
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()

                
                
                let convoIdValue = try convoId.toCBORValue()
                map = map.adding(key: "convoId", value: convoIdValue)
                
                
                
                if let value = targetDid {
                    // Encode optional property even if it's an empty array for CBOR
                    let targetDidValue = try value.toCBORValue()
                    map = map.adding(key: "targetDid", value: targetDidValue)
                }
                
                
                
                if let value = commit {
                    // Encode optional property even if it's an empty array for CBOR
                    let commitValue = try value.toCBORValue()
                    map = map.adding(key: "commit", value: commitValue)
                }
                
                

                return map
            }
        }
    
public struct Output: ATProtocolCodable {
        
        
        public let success: Bool
        
        public let newEpoch: Int
        
        
        
        // Standard public initializer
        public init(
            
            
            success: Bool,
            
            newEpoch: Int
            
            
        ) {
            
            
            self.success = success
            
            self.newEpoch = newEpoch
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.success = try container.decode(Bool.self, forKey: .success)
            
            
            self.newEpoch = try container.decode(Int.self, forKey: .newEpoch)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(success, forKey: .success)
            
            
            try container.encode(newEpoch, forKey: .newEpoch)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let successValue = try success.toCBORValue()
            map = map.adding(key: "success", value: successValue)
            
            
            
            let newEpochValue = try newEpoch.toCBORValue()
            map = map.adding(key: "newEpoch", value: newEpochValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case success
            case newEpoch
        }
        
    }
        
public enum Error: String, Swift.Error, CustomStringConvertible {
                case convoNotFound = "ConvoNotFound.Conversation not found"
                case notMember = "NotMember.Caller is not a member of the conversation"
                case lastMember = "LastMember.Cannot leave as the last member (delete the conversation instead)"
            public var description: String {
                return self.rawValue
            }
        }



}

extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - leaveConvo

    /// Leave an MLS conversation
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func leaveConvo(
        
        input: BlueCatbirdMlsLeaveConvo.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsLeaveConvo.Output?) {
        let endpoint = "blue.catbird.mls.leaveConvo"
        
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

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.leaveConvo")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsLeaveConvo.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.leaveConvo: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

