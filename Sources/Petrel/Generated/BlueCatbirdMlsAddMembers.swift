import Foundation



// lexicon: 1, id: blue.catbird.mls.addMembers


public struct BlueCatbirdMlsAddMembers { 

    public static let typeIdentifier = "blue.catbird.mls.addMembers"
public struct Input: ATProtocolCodable {
            public let convoId: String
            public let didList: [DID]
            public let commit: String?
            public let welcomeMessage: String?

            // Standard public initializer
            public init(convoId: String, didList: [DID], commit: String? = nil, welcomeMessage: String? = nil) {
                self.convoId = convoId
                self.didList = didList
                self.commit = commit
                self.welcomeMessage = welcomeMessage
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.convoId = try container.decode(String.self, forKey: .convoId)
                
                
                self.didList = try container.decode([DID].self, forKey: .didList)
                
                
                self.commit = try container.decodeIfPresent(String.self, forKey: .commit)
                
                
                self.welcomeMessage = try container.decodeIfPresent(String.self, forKey: .welcomeMessage)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(convoId, forKey: .convoId)
                
                
                try container.encode(didList, forKey: .didList)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(commit, forKey: .commit)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(welcomeMessage, forKey: .welcomeMessage)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case convoId
                case didList
                case commit
                case welcomeMessage
            }
            
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()

                
                
                let convoIdValue = try convoId.toCBORValue()
                map = map.adding(key: "convoId", value: convoIdValue)
                
                
                
                let didListValue = try didList.toCBORValue()
                map = map.adding(key: "didList", value: didListValue)
                
                
                
                if let value = commit {
                    // Encode optional property even if it's an empty array for CBOR
                    let commitValue = try value.toCBORValue()
                    map = map.adding(key: "commit", value: commitValue)
                }
                
                
                
                if let value = welcomeMessage {
                    // Encode optional property even if it's an empty array for CBOR
                    let welcomeMessageValue = try value.toCBORValue()
                    map = map.adding(key: "welcomeMessage", value: welcomeMessageValue)
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
                case keyPackageNotFound = "KeyPackageNotFound.Key package not found for one or more members"
                case alreadyMember = "AlreadyMember.One or more DIDs are already members"
                case tooManyMembers = "TooManyMembers.Would exceed maximum member count"
            public var description: String {
                return self.rawValue
            }
        }



}

extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - addMembers

    /// Add new members to an existing MLS conversation Add members to an existing MLS conversation
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func addMembers(
        
        input: BlueCatbirdMlsAddMembers.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsAddMembers.Output?) {
        let endpoint = "blue.catbird.mls.addMembers"
        
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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.addMembers")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsAddMembers.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.addMembers: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

