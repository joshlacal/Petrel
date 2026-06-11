import Foundation

// lexicon: 1, id: app.bsky.actor.getSuggestions

public enum AppBskyActorGetSuggestions {
    public static let typeIdentifier = "app.bsky.actor.getSuggestions"
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
        public let cursor: String?

        public let actors: [AppBskyActorDefs.ProfileView]

        public let recId: Int?

        public let recIdStr: String?

        /// Standard public initializer
        public init(
            cursor: String? = nil,

            actors: [AppBskyActorDefs.ProfileView],

            recId: Int? = nil,

            recIdStr: String? = nil

        ) {
            self.cursor = cursor

            self.actors = actors

            self.recId = recId

            self.recIdStr = recIdStr
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            do {
                cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
            } catch {
                // Forward compatibility: a malformed optional field must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'cursor' — degrading to nil: \(error)")
                cursor = nil
            }

            actors = try container.decode([AppBskyActorDefs.ProfileView].self, forKey: .actors)

            do {
                recId = try container.decodeIfPresent(Int.self, forKey: .recId)
            } catch {
                // Forward compatibility: a malformed optional field must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'recId' — degrading to nil: \(error)")
                recId = nil
            }

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

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)

            try container.encode(actors, forKey: .actors)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(recId, forKey: .recId)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(recIdStr, forKey: .recIdStr)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR
                let cursorValue = try value.toCBORValue()
                map = map.adding(key: "cursor", value: cursorValue)
            }

            let actorsValue = try actors.toCBORValue()
            map = map.adding(key: "actors", value: actorsValue)

            if let value = recId {
                // Encode optional property even if it's an empty array for CBOR
                let recIdValue = try value.toCBORValue()
                map = map.adding(key: "recId", value: recIdValue)
            }

            if let value = recIdStr {
                // Encode optional property even if it's an empty array for CBOR
                let recIdStrValue = try value.toCBORValue()
                map = map.adding(key: "recIdStr", value: recIdStrValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case cursor
            case actors
            case recId
            case recIdStr
        }
    }
}

public extension ATProtoClient.App.Bsky.Actor {
    // MARK: - getSuggestions

    /// Get a list of suggested actors. Expected use is discovery of accounts to follow during new account onboarding.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getSuggestions(input: AppBskyActorGetSuggestions.Parameters) async throws -> (responseCode: Int, data: AppBskyActorGetSuggestions.Output?) {
        let endpoint = "app.bsky.actor.getSuggestions"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.actor.getSuggestions")
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
                let decodedData = try decoder.decode(AppBskyActorGetSuggestions.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.actor.getSuggestions: \(error)")
                return (responseCode, nil)
            }
        } else {
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
