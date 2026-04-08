import Foundation



// lexicon: 1, id: place.stream.live.searchActorsTypeahead


public struct PlaceStreamLiveSearchActorsTypeahead { 

    public static let typeIdentifier = "place.stream.live.searchActorsTypeahead"
        
public struct Actor: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "place.stream.live.searchActorsTypeahead#actor"
            public let did: DID
            public let handle: Handle

        public init(
            did: DID, handle: Handle
        ) {
            self.did = did
            self.handle = handle
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.did = try container.decode(DID.self, forKey: .did)
            } catch {
                LogManager.logError("Decoding error for required property 'did': \(error)")
                throw error
            }
            do {
                self.handle = try container.decode(Handle.self, forKey: .handle)
            } catch {
                LogManager.logError("Decoding error for required property 'handle': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(did, forKey: .did)
            try container.encode(handle, forKey: .handle)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(did)
            hasher.combine(handle)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if did != other.did {
                return false
            }
            if handle != other.handle {
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
            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)
            let handleValue = try handle.toCBORValue()
            map = map.adding(key: "handle", value: handleValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
            case handle
        }
    }    
public struct Parameters: Parametrizable {
        public let q: String?
        public let limit: Int?
        
        public init(
            q: String? = nil, 
            limit: Int? = nil
            ) {
            self.q = q
            self.limit = limit
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let actors: [Actor]
        
        
        
        // Standard public initializer
        public init(
            
            
            actors: [Actor]
            
            
        ) {
            
            
            self.actors = actors
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.actors = try container.decode([Actor].self, forKey: .actors)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(actors, forKey: .actors)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let actorsValue = try actors.toCBORValue()
            map = map.adding(key: "actors", value: actorsValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case actors
        }
        
    }




}



extension ATProtoClient.Place.Stream.Live {
    // MARK: - searchActorsTypeahead

    /// Find actor suggestions for a prefix search term. Expected use is for auto-completion during text field entry.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func searchActorsTypeahead(input: PlaceStreamLiveSearchActorsTypeahead.Parameters) async throws -> (responseCode: Int, data: PlaceStreamLiveSearchActorsTypeahead.Output?) {
        let endpoint = "place.stream.live.searchActorsTypeahead"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "place.stream.live.searchActorsTypeahead")
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
                let decodedData = try decoder.decode(PlaceStreamLiveSearchActorsTypeahead.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for place.stream.live.searchActorsTypeahead: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

