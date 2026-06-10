import Foundation

// lexicon: 1, id: place.stream.live.stopLivestream

public enum PlaceStreamLiveStopLivestream {
    public static let typeIdentifier = "place.stream.live.stopLivestream"
    public struct Input: ATProtocolCodable {
        /// Standard public initializer
        public init() {}

        public func toCBORValue() throws -> Any {
            return OrderedCBORMap()
        }
    }

    public struct Output: ATProtocolCodable {
        public let uri: URI

        public let cid: CID

        /// Standard public initializer
        public init(
            uri: URI,

            cid: CID

        ) {
            self.uri = uri

            self.cid = cid
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            uri = try container.decode(URI.self, forKey: .uri)

            cid = try container.decode(CID.self, forKey: .cid)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(uri, forKey: .uri)

            try container.encode(cid, forKey: .cid)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let uriValue = try uri.toCBORValue()
            map = map.adding(key: "uri", value: uriValue)

            let cidValue = try cid.toCBORValue()
            map = map.adding(key: "cid", value: cidValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case uri
            case cid
        }
    }
}

public extension ATProtoClient.Place.Stream.Live {
    // MARK: - stopLivestream

    // Stop your current livestream, updating your current place.stream.livestream record and ceasing the flow of video.
    //
    // - Parameter input: The input parameters for the request

    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func stopLivestream(
        input: PlaceStreamLiveStopLivestream.Input

    ) async throws -> (responseCode: Int, data: PlaceStreamLiveStopLivestream.Output?) {
        let endpoint = "place.stream.live.stopLivestream"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        headers["Accept"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)

        let queryItems: [URLQueryItem]? = nil

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "place.stream.live.stopLivestream")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        // Only validate Content-Type and decode on success. Error responses
        // (4xx/5xx) may have missing or different Content-Type headers and
        // are handled by the caller via the status code.
        if (200 ... 299).contains(responseCode) {
            guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
                throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
            }

            if !contentType.lowercased().contains("application/json") {
                throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
            }

            do {
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(PlaceStreamLiveStopLivestream.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for place.stream.live.stopLivestream: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
