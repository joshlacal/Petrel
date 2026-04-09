import Foundation



// lexicon: 1, id: place.stream.live.getRecommendations


public struct PlaceStreamLiveGetRecommendations { 

    public static let typeIdentifier = "place.stream.live.getRecommendations"
        
public struct LivestreamRecommendation: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "place.stream.live.getRecommendations#livestreamRecommendation"
            public let did: DID
            public let source: String

        public init(
            did: DID, source: String
        ) {
            self.did = did
            self.source = source
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
                self.source = try container.decode(String.self, forKey: .source)
            } catch {
                LogManager.logError("Decoding error for required property 'source': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(did, forKey: .did)
            try container.encode(source, forKey: .source)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(did)
            hasher.combine(source)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if did != other.did {
                return false
            }
            if source != other.source {
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
            let sourceValue = try source.toCBORValue()
            map = map.adding(key: "source", value: sourceValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
            case source
        }
    }    
public struct Parameters: Parametrizable {
        public let userDID: DID
        
        public init(
            userDID: DID
            ) {
            self.userDID = userDID
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let recommendations: [OutputRecommendationsUnion]
        
        public let userDID: DID?
        
        
        
        // Standard public initializer
        public init(
            
            
            recommendations: [OutputRecommendationsUnion],
            
            userDID: DID? = nil
            
            
        ) {
            
            
            self.recommendations = recommendations
            
            self.userDID = userDID
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.recommendations = try container.decode([OutputRecommendationsUnion].self, forKey: .recommendations)
            
            
            self.userDID = try container.decodeIfPresent(DID.self, forKey: .userDID)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(recommendations, forKey: .recommendations)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(userDID, forKey: .userDID)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let recommendationsValue = try recommendations.toCBORValue()
            map = map.adding(key: "recommendations", value: recommendationsValue)
            
            
            
            if let value = userDID {
                // Encode optional property even if it's an empty array for CBOR
                let userDIDValue = try value.toCBORValue()
                map = map.adding(key: "userDID", value: userDIDValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case recommendations
            case userDID
        }
        
    }






public enum OutputRecommendationsUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
    case placeStreamLiveGetRecommendationsLivestreamRecommendation(PlaceStreamLiveGetRecommendations.LivestreamRecommendation)
    case unexpected(ATProtocolValueContainer)
    public init(_ value: PlaceStreamLiveGetRecommendations.LivestreamRecommendation) {
        self = .placeStreamLiveGetRecommendationsLivestreamRecommendation(value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)

        switch typeValue {
        case "place.stream.live.getRecommendations#livestreamRecommendation":
            let value = try PlaceStreamLiveGetRecommendations.LivestreamRecommendation(from: decoder)
            self = .placeStreamLiveGetRecommendationsLivestreamRecommendation(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .placeStreamLiveGetRecommendationsLivestreamRecommendation(let value):
            try container.encode("place.stream.live.getRecommendations#livestreamRecommendation", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let container):
            try container.encode(to: encoder)
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .placeStreamLiveGetRecommendationsLivestreamRecommendation(let value):
            hasher.combine("place.stream.live.getRecommendations#livestreamRecommendation")
            hasher.combine(value)
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: OutputRecommendationsUnion, rhs: OutputRecommendationsUnion) -> Bool {
        switch (lhs, rhs) {
        case (.placeStreamLiveGetRecommendationsLivestreamRecommendation(let lhsValue),
              .placeStreamLiveGetRecommendationsLivestreamRecommendation(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? OutputRecommendationsUnion else { return false }
        return self == other
    }
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        // Create an ordered map to maintain field order
        var map = OrderedCBORMap()
        
        switch self {
        case .placeStreamLiveGetRecommendationsLivestreamRecommendation(let value):
            map = map.adding(key: "$type", value: "place.stream.live.getRecommendations#livestreamRecommendation")
            
            let valueDict = try value.toCBORValue()

            // If the value is already an OrderedCBORMap, merge its entries
            if let orderedMap = valueDict as? OrderedCBORMap {
                for (key, value) in orderedMap.entries where key != "$type" {
                    map = map.adding(key: key, value: value)
                }
            } else if let dict = valueDict as? [String: Any] {
                // Otherwise add each key-value pair from the dictionary
                for (key, value) in dict where key != "$type" {
                    map = map.adding(key: key, value: value)
                }
            }
            return map
        case .unexpected(let container):
            return try container.toCBORValue()
        }
    }
}


}



extension ATProtoClient.Place.Stream.Live {
    // MARK: - getRecommendations

    /// Get the list of streamers recommended by a user
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getRecommendations(input: PlaceStreamLiveGetRecommendations.Parameters) async throws -> (responseCode: Int, data: PlaceStreamLiveGetRecommendations.Output?) {
        let endpoint = "place.stream.live.getRecommendations"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "place.stream.live.getRecommendations")
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
                let decodedData = try decoder.decode(PlaceStreamLiveGetRecommendations.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for place.stream.live.getRecommendations: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

