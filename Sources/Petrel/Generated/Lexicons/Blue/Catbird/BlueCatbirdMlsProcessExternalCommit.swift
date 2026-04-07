import Foundation



// lexicon: 1, id: blue.catbird.mls.processExternalCommit


public struct BlueCatbirdMlsProcessExternalCommit { 

    public static let typeIdentifier = "blue.catbird.mls.processExternalCommit"
public struct Input: ATProtocolCodable {
        public let convoId: String
        public let externalCommit: String
        public let idempotencyKey: String?
        public let groupInfo: String?

        /// Standard public initializer
        public init(convoId: String, externalCommit: String, idempotencyKey: String? = nil, groupInfo: String? = nil) {
            self.convoId = convoId
            self.externalCommit = externalCommit
            self.idempotencyKey = idempotencyKey
            self.groupInfo = groupInfo
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.convoId = try container.decode(String.self, forKey: .convoId)
            self.externalCommit = try container.decode(String.self, forKey: .externalCommit)
            self.idempotencyKey = try container.decodeIfPresent(String.self, forKey: .idempotencyKey)
            self.groupInfo = try container.decodeIfPresent(String.self, forKey: .groupInfo)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(externalCommit, forKey: .externalCommit)
            try container.encodeIfPresent(idempotencyKey, forKey: .idempotencyKey)
            try container.encodeIfPresent(groupInfo, forKey: .groupInfo)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let externalCommitValue = try externalCommit.toCBORValue()
            map = map.adding(key: "externalCommit", value: externalCommitValue)
            if let value = idempotencyKey {
                let idempotencyKeyValue = try value.toCBORValue()
                map = map.adding(key: "idempotencyKey", value: idempotencyKeyValue)
            }
            if let value = groupInfo {
                let groupInfoValue = try value.toCBORValue()
                map = map.adding(key: "groupInfo", value: groupInfoValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case convoId
            case externalCommit
            case idempotencyKey
            case groupInfo
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let epoch: Int?
        
        public let rejoinedAt: ATProtocolDate?
        
        
        
        // Standard public initializer
        public init(
            
            
            epoch: Int? = nil,
            
            rejoinedAt: ATProtocolDate? = nil
            
            
        ) {
            
            
            self.epoch = epoch
            
            self.rejoinedAt = rejoinedAt
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.epoch = try container.decodeIfPresent(Int.self, forKey: .epoch)
            
            
            self.rejoinedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .rejoinedAt)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(epoch, forKey: .epoch)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(rejoinedAt, forKey: .rejoinedAt)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            if let value = epoch {
                // Encode optional property even if it's an empty array for CBOR
                let epochValue = try value.toCBORValue()
                map = map.adding(key: "epoch", value: epochValue)
            }
            
            
            
            if let value = rejoinedAt {
                // Encode optional property even if it's an empty array for CBOR
                let rejoinedAtValue = try value.toCBORValue()
                map = map.adding(key: "rejoinedAt", value: rejoinedAtValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case epoch
            case rejoinedAt
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case unauthorized = "Unauthorized."
                case invalidCommit = "InvalidCommit."
                case invalidGroupInfo = "InvalidGroupInfo."
            public var description: String {
                return self.rawValue
            }

            public var errorName: String {
                // Extract just the error name from the raw value
                let parts = self.rawValue.split(separator: ".")
                return String(parts.first ?? "")
            }
        }



}

extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - processExternalCommit

    /// Process an external commit for a conversation. This allows a client to add itself to a group using a cached GroupInfo.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func processExternalCommit(
        
        input: BlueCatbirdMlsProcessExternalCommit.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsProcessExternalCommit.Output?) {
        let endpoint = "blue.catbird.mls.processExternalCommit"
        
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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.processExternalCommit")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsProcessExternalCommit.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.processExternalCommit: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

