import Foundation

// lexicon: 1, id: place.stream.live.getLiveUsers

public enum PlaceStreamLiveGetLiveUsers {
    public static let typeIdentifier = "place.stream.live.getLiveUsers"
    public struct Parameters: Parametrizable {
        public let limit: Int?
        public let before: ATProtocolDate?

        public init(
            limit: Int? = nil,
            before: ATProtocolDate? = nil
        ) {
            self.limit = limit
            self.before = before
        }
    }

    public struct Output: ATProtocolCodable {
        public let streams: [PlaceStreamLivestream.LivestreamView]?

        /// Standard public initializer
        public init(
            streams: [PlaceStreamLivestream.LivestreamView]? = nil

        ) {
            self.streams = streams
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            do {
                streams = try container.decodeIfPresent([PlaceStreamLivestream.LivestreamView].self, forKey: .streams)
            } catch {
                // Forward compatibility: a malformed optional field must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'streams' — degrading to nil: \(error)")
                streams = nil
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(streams, forKey: .streams)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            if let value = streams {
                // Encode optional property even if it's an empty array for CBOR
                let streamsValue = try value.toCBORValue()
                map = map.adding(key: "streams", value: streamsValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case streams
        }
    }
}

public extension ATProtoClient.Place.Stream.Live {
    // MARK: - getLiveUsers

    /// Get a list of livestream segments for a user
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getLiveUsers(input: PlaceStreamLiveGetLiveUsers.Parameters) async throws -> (responseCode: Int, data: PlaceStreamLiveGetLiveUsers.Output?) {
        let endpoint = "place.stream.live.getLiveUsers"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "place.stream.live.getLiveUsers")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        // Only validate Content-Type and decode on success. Error responses
        // (4xx/5xx) may have missing or different Content-Type headers and
        // are handled via the status code / structured error parser below.
        if (200 ... 299).contains(responseCode) {
            guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
                throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
            }

            if !contentType.lowercased().contains("application/json") {
                throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
            }

            do {
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(PlaceStreamLiveGetLiveUsers.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for place.stream.live.getLiveUsers: \(error)")
                return (responseCode, nil)
            }
        } else {
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
