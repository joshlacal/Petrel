import Foundation



// lexicon: 1, id: blue.catbird.mls.getOptInStatus


public struct BlueCatbirdMlsGetOptInStatus { 

    public static let typeIdentifier = "blue.catbird.mls.getOptInStatus"
        
public struct OptInStatus: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mls.getOptInStatus#optInStatus"
            public let did: DID
            public let optedIn: Bool
            public let optedInAt: ATProtocolDate?

        // Standard initializer
        public init(
            did: DID, optedIn: Bool, optedInAt: ATProtocolDate?
        ) {
            
            self.did = did
            self.optedIn = optedIn
            self.optedInAt = optedInAt
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.did = try container.decode(DID.self, forKey: .did)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'did': \(error)")
                
                throw error
            }
            do {
                
                
                self.optedIn = try container.decode(Bool.self, forKey: .optedIn)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'optedIn': \(error)")
                
                throw error
            }
            do {
                
                
                self.optedInAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .optedInAt)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'optedInAt': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(did, forKey: .did)
            
            
            
            
            try container.encode(optedIn, forKey: .optedIn)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(optedInAt, forKey: .optedInAt)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(did)
            hasher.combine(optedIn)
            if let value = optedInAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.did != other.did {
                return false
            }
            
            
            
            
            if self.optedIn != other.optedIn {
                return false
            }
            
            
            
            
            if optedInAt != other.optedInAt {
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

            
            
            
            
            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)
            
            
            
            
            
            
            let optedInValue = try optedIn.toCBORValue()
            map = map.adding(key: "optedIn", value: optedInValue)
            
            
            
            
            
            if let value = optedInAt {
                // Encode optional property even if it's an empty array for CBOR
                
                let optedInAtValue = try value.toCBORValue()
                map = map.adding(key: "optedInAt", value: optedInAtValue)
            }
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
            case optedIn
            case optedInAt
        }
    }    
public struct Parameters: Parametrizable {
        public let dids: [DID]
        
        public init(
            dids: [DID]
            ) {
            self.dids = dids
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let statuses: [OptInStatus]
        
        
        
        // Standard public initializer
        public init(
            
            
            statuses: [OptInStatus]
            
            
        ) {
            
            
            self.statuses = statuses
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.statuses = try container.decode([OptInStatus].self, forKey: .statuses)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(statuses, forKey: .statuses)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let statusesValue = try statuses.toCBORValue()
            map = map.adding(key: "statuses", value: statusesValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case statuses
        }
        
    }




}



extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - getOptInStatus

    /// Check if users have opted into MLS chat Query opt-in status for a list of users. Returns array of status objects with DID, opt-in boolean, and optional timestamp.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getOptInStatus(input: BlueCatbirdMlsGetOptInStatus.Parameters) async throws -> (responseCode: Int, data: BlueCatbirdMlsGetOptInStatus.Output?) {
        let endpoint = "blue.catbird.mls.getOptInStatus"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.getOptInStatus")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsGetOptInStatus.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.getOptInStatus: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

