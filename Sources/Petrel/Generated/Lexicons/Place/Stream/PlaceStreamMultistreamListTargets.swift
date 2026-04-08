import Foundation



// lexicon: 1, id: place.stream.multistream.listTargets


public struct PlaceStreamMultistreamListTargets { 

    public static let typeIdentifier = "place.stream.multistream.listTargets"
        
public struct Record: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "place.stream.multistream.listTargets#record"
            public let uri: ATProtocolURI
            public let cid: CID
            public let value: ATProtocolValueContainer

        public init(
            uri: ATProtocolURI, cid: CID, value: ATProtocolValueContainer
        ) {
            self.uri = uri
            self.cid = cid
            self.value = value
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.uri = try container.decode(ATProtocolURI.self, forKey: .uri)
            } catch {
                LogManager.logError("Decoding error for required property 'uri': \(error)")
                throw error
            }
            do {
                self.cid = try container.decode(CID.self, forKey: .cid)
            } catch {
                LogManager.logError("Decoding error for required property 'cid': \(error)")
                throw error
            }
            do {
                self.value = try container.decode(ATProtocolValueContainer.self, forKey: .value)
            } catch {
                LogManager.logError("Decoding error for required property 'value': \(error)")
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
            if uri != other.uri {
                return false
            }
            if cid != other.cid {
                return false
            }
            if value != other.value {
                return false
            }
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let uriValue = try uri.toCBORValue()
            map = map.adding(key: "uri", value: uriValue)
            let cidValue = try cid.toCBORValue()
            map = map.adding(key: "cid", value: cidValue)
            let valueValue = try value.toCBORValue()
            map = map.adding(key: "value", value: valueValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
            case cid
            case value
        }
    }    
public struct Parameters: Parametrizable {
        public let limit: Int?
        public let cursor: String?
        
        public init(
            limit: Int? = nil, 
            cursor: String? = nil
            ) {
            self.limit = limit
            self.cursor = cursor
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let targets: [PlaceStreamMultistreamDefs.TargetView]
        
        public let cursor: String?
        
        
        
        // Standard public initializer
        public init(
            
            
            targets: [PlaceStreamMultistreamDefs.TargetView],
            
            cursor: String? = nil
            
            
        ) {
            
            
            self.targets = targets
            
            self.cursor = cursor
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.targets = try container.decode([PlaceStreamMultistreamDefs.TargetView].self, forKey: .targets)
            
            
            self.cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(targets, forKey: .targets)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let targetsValue = try targets.toCBORValue()
            map = map.adding(key: "targets", value: targetsValue)
            
            
            
            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR
                let cursorValue = try value.toCBORValue()
                map = map.adding(key: "cursor", value: cursorValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case targets
            case cursor
        }
        
    }




}



extension ATProtoClient.Place.Stream.Multistream {
    // MARK: - listTargets

    /// List a range of targets for rebroadcasting a Streamplace stream.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func listTargets(input: PlaceStreamMultistreamListTargets.Parameters) async throws -> (responseCode: Int, data: PlaceStreamMultistreamListTargets.Output?) {
        let endpoint = "place.stream.multistream.listTargets"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "place.stream.multistream.listTargets")
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
                let decodedData = try decoder.decode(PlaceStreamMultistreamListTargets.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for place.stream.multistream.listTargets: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

