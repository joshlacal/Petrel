import Foundation

// lexicon: 1, id: app.bsky.unspecced.getSuggestedUsersForSeeMoreSkeleton

public enum AppBskyUnspeccedGetSuggestedUsersForSeeMoreSkeleton {
    public static let typeIdentifier = "app.bsky.unspecced.getSuggestedUsersForSeeMoreSkeleton"
    public struct Parameters: Parametrizable {
        public let viewer: DID?
        public let category: String?
        public let limit: Int?

        public init(
            viewer: DID? = nil,
            category: String? = nil,
            limit: Int? = nil
        ) {
            self.viewer = viewer
            self.category = category
            self.limit = limit
        }
    }

    public struct Output: ATProtocolCodable {
        public let dids: [DID]

        public let recIdStr: String?

        /// Standard public initializer
        public init(
            dids: [DID],

            recIdStr: String? = nil

        ) {
            self.dids = dids

            self.recIdStr = recIdStr
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            dids = try container.decode([DID].self, forKey: .dids)

            do {
                recIdStr = try container.decodeIfPresent(String.self, forKey: .recIdStr)
            } catch {
                // Forward compatibility: a malformed optional field must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'recIdStr' — degrading to nil: \(error)")
                recIdStr = nil
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(dids, forKey: .dids)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(recIdStr, forKey: .recIdStr)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let didsValue = try dids.toCBORValue()
            map = map.adding(key: "dids", value: didsValue)

            if let value = recIdStr {
                // Encode optional property even if it's an empty array for CBOR
                let recIdStrValue = try value.toCBORValue()
                map = map.adding(key: "recIdStr", value: recIdStrValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case dids
            case recIdStr
        }
    }
}

public extension ATProtoClient.App.Bsky.Unspecced {
    // MARK: - getSuggestedUsersForSeeMoreSkeleton

    /// Get a skeleton of suggested users for the See More page. Intended to be called and hydrated by app.bsky.unspecced.getSuggestedUsersForSeeMore
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getSuggestedUsersForSeeMoreSkeleton(input: AppBskyUnspeccedGetSuggestedUsersForSeeMoreSkeleton.Parameters) async throws -> (responseCode: Int, data: AppBskyUnspeccedGetSuggestedUsersForSeeMoreSkeleton.Output?) {
        let endpoint = "app.bsky.unspecced.getSuggestedUsersForSeeMoreSkeleton"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.unspecced.getSuggestedUsersForSeeMoreSkeleton")
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
                let decodedData = try decoder.decode(AppBskyUnspeccedGetSuggestedUsersForSeeMoreSkeleton.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.unspecced.getSuggestedUsersForSeeMoreSkeleton: \(error)")
                return (responseCode, nil)
            }
        } else {
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
