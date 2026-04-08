import Foundation



// lexicon: 1, id: place.stream.multistream.createTarget


public struct PlaceStreamMultistreamCreateTarget { 

    public static let typeIdentifier = "place.stream.multistream.createTarget"
public struct Input: ATProtocolCodable {
        public let multistreamTarget: PlaceStreamMultistreamTarget

        /// Standard public initializer
        public init(multistreamTarget: PlaceStreamMultistreamTarget) {
            self.multistreamTarget = multistreamTarget
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.multistreamTarget = try container.decode(PlaceStreamMultistreamTarget.self, forKey: .multistreamTarget)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(multistreamTarget, forKey: .multistreamTarget)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let multistreamTargetValue = try multistreamTarget.toCBORValue()
            map = map.adding(key: "multistreamTarget", value: multistreamTargetValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case multistreamTarget
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
    // MARK: - createTarget

    /// Create a new target for rebroadcasting a Streamplace stream.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func createTarget(
        
        input: PlaceStreamMultistreamCreateTarget.Input
        
    ) async throws -> (responseCode: Int, data: PlaceStreamMultistreamCreateTarget.Output?) {
        let endpoint = "place.stream.multistream.createTarget"
        
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
        let serviceDID = await networkService.getServiceDID(for: "place.stream.multistream.createTarget")
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
                let decodedData = try decoder.decode(PlaceStreamMultistreamCreateTarget.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for place.stream.multistream.createTarget: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

