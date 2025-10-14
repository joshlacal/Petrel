import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// lexicon: 1, id: com.atproto.temp.checkSignupQueue

public enum ComAtprotoTempCheckSignupQueue {
    public static let typeIdentifier = "com.atproto.temp.checkSignupQueue"

    public struct Output: ATProtocolCodable {
        public let activated: Bool

        public let placeInQueue: Int?

        public let estimatedTimeMs: Int?

        // Standard public initializer
        public init(
            activated: Bool,

            placeInQueue: Int? = nil,

            estimatedTimeMs: Int? = nil

        ) {
            self.activated = activated

            self.placeInQueue = placeInQueue

            self.estimatedTimeMs = estimatedTimeMs
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            activated = try container.decode(Bool.self, forKey: .activated)

            placeInQueue = try container.decodeIfPresent(Int.self, forKey: .placeInQueue)

            estimatedTimeMs = try container.decodeIfPresent(Int.self, forKey: .estimatedTimeMs)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(activated, forKey: .activated)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(placeInQueue, forKey: .placeInQueue)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(estimatedTimeMs, forKey: .estimatedTimeMs)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let activatedValue = try activated.toCBORValue()
            map = map.adding(key: "activated", value: activatedValue)

            if let value = placeInQueue {
                // Encode optional property even if it's an empty array for CBOR
                let placeInQueueValue = try value.toCBORValue()
                map = map.adding(key: "placeInQueue", value: placeInQueueValue)
            }

            if let value = estimatedTimeMs {
                // Encode optional property even if it's an empty array for CBOR
                let estimatedTimeMsValue = try value.toCBORValue()
                map = map.adding(key: "estimatedTimeMs", value: estimatedTimeMsValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case activated
            case placeInQueue
            case estimatedTimeMs
        }
    }
}

public extension ATProtoClient.Com.Atproto.Temp {
    // MARK: - checkSignupQueue

    /// Check accounts location in signup queue.
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func checkSignupQueue() async throws -> (responseCode: Int, data: ComAtprotoTempCheckSignupQueue.Output?) {
        let endpoint = "com.atproto.temp.checkSignupQueue"

        let queryItems: [URLQueryItem]? = nil

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "com.atproto.temp.checkSignupQueue")
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
        if (200 ... 299).contains(responseCode) {
            do {
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(ComAtprotoTempCheckSignupQueue.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for com.atproto.temp.checkSignupQueue: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
