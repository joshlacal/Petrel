import Foundation



// lexicon: 1, id: place.stream.ingest.getIngestUrls


public struct PlaceStreamIngestGetIngestUrls { 

    public static let typeIdentifier = "place.stream.ingest.getIngestUrls"    
public struct Parameters: Parametrizable {
        
        public init(
            ) {
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let ingests: [OutputIngestsUnion]
        
        
        
        // Standard public initializer
        public init(
            
            
            ingests: [OutputIngestsUnion]
            
            
        ) {
            
            
            self.ingests = ingests
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.ingests = try container.decode([OutputIngestsUnion].self, forKey: .ingests)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(ingests, forKey: .ingests)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let ingestsValue = try ingests.toCBORValue()
            map = map.adding(key: "ingests", value: ingestsValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case ingests
        }
        
    }






public enum OutputIngestsUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
    case placeStreamIngestDefsIngest(PlaceStreamIngestDefs.Ingest)
    case unexpected(ATProtocolValueContainer)
    public init(_ value: PlaceStreamIngestDefs.Ingest) {
        self = .placeStreamIngestDefsIngest(value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)

        switch typeValue {
        case "place.stream.ingest.defs#ingest":
            let value = try PlaceStreamIngestDefs.Ingest(from: decoder)
            self = .placeStreamIngestDefsIngest(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .placeStreamIngestDefsIngest(let value):
            try container.encode("place.stream.ingest.defs#ingest", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let container):
            try container.encode(to: encoder)
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .placeStreamIngestDefsIngest(let value):
            hasher.combine("place.stream.ingest.defs#ingest")
            hasher.combine(value)
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: OutputIngestsUnion, rhs: OutputIngestsUnion) -> Bool {
        switch (lhs, rhs) {
        case (.placeStreamIngestDefsIngest(let lhsValue),
              .placeStreamIngestDefsIngest(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? OutputIngestsUnion else { return false }
        return self == other
    }
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        // Create an ordered map to maintain field order
        var map = OrderedCBORMap()
        
        switch self {
        case .placeStreamIngestDefsIngest(let value):
            map = map.adding(key: "$type", value: "place.stream.ingest.defs#ingest")
            
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



extension ATProtoClient.Place.Stream.Ingest {
    // MARK: - getIngestUrls

    /// Get ingest URLs for a Streamplace station.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getIngestUrls(input: PlaceStreamIngestGetIngestUrls.Parameters) async throws -> (responseCode: Int, data: PlaceStreamIngestGetIngestUrls.Output?) {
        let endpoint = "place.stream.ingest.getIngestUrls"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "place.stream.ingest.getIngestUrls")
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
                let decodedData = try decoder.decode(PlaceStreamIngestGetIngestUrls.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for place.stream.ingest.getIngestUrls: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

