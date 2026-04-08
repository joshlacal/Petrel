import Foundation



// lexicon: 1, id: place.stream.multistream.putTarget


public struct PlaceStreamMultistreamPutTarget { 

    public static let typeIdentifier = "place.stream.multistream.putTarget"
public struct Input: ATProtocolCodable {
        public let multistreamTarget: PlaceStreamMultistreamTarget
        public let rkey: RecordKey?

        /// Standard public initializer
        public init(multistreamTarget: PlaceStreamMultistreamTarget, rkey: RecordKey? = nil) {
            self.multistreamTarget = multistreamTarget
            self.rkey = rkey
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.multistreamTarget = try container.decode(PlaceStreamMultistreamTarget.self, forKey: .multistreamTarget)
            self.rkey = try container.decodeIfPresent(RecordKey.self, forKey: .rkey)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(multistreamTarget, forKey: .multistreamTarget)
            try container.encodeIfPresent(rkey, forKey: .rkey)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let multistreamTargetValue = try multistreamTarget.toCBORValue()
            map = map.adding(key: "multistreamTarget", value: multistreamTargetValue)
            if let value = rkey {
                let rkeyValue = try value.toCBORValue()
                map = map.adding(key: "rkey", value: rkeyValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case multistreamTarget
            case rkey
        }
    }
    public typealias Output = PlaceStreamMultistreamDefs.TargetView
            
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case invalidTargetUrl = "InvalidTargetUrl.The provided target URL is invalid or unreachable."
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

extension ATProtoClient.Place.Stream.Multistream {
    // MARK: - putTarget

    /// Update an existing target for rebroadcasting a Streamplace stream.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func putTarget(
        
        input: PlaceStreamMultistreamPutTarget.Input
        
    ) async throws -> (responseCode: Int, data: PlaceStreamMultistreamPutTarget.Output?) {
        let endpoint = "place.stream.multistream.putTarget"
        
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
        let serviceDID = await networkService.getServiceDID(for: "place.stream.multistream.putTarget")
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
                let decodedData = try decoder.decode(PlaceStreamMultistreamPutTarget.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for place.stream.multistream.putTarget: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

