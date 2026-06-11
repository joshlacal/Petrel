import Foundation

// lexicon: 1, id: app.bsky.embed.getEmbedExternalView

public enum AppBskyEmbedGetEmbedExternalView {
    public static let typeIdentifier = "app.bsky.embed.getEmbedExternalView"
    public struct Parameters: Parametrizable {
        public let url: URI
        public let uris: [ATProtocolURI]

        public init(
            url: URI,
            uris: [ATProtocolURI]
        ) {
            self.url = url
            self.uris = uris
        }
    }

    public struct Output: ATProtocolCodable {
        public let view: AppBskyEmbedExternal.View?

        public let associatedRefs: [ComAtprotoRepoStrongRef]?

        public let associatedRecords: [ATProtocolValueContainer]?

        /// Standard public initializer
        public init(
            view: AppBskyEmbedExternal.View? = nil,

            associatedRefs: [ComAtprotoRepoStrongRef]? = nil,

            associatedRecords: [ATProtocolValueContainer]? = nil

        ) {
            self.view = view

            self.associatedRefs = associatedRefs

            self.associatedRecords = associatedRecords
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            do {
                view = try container.decodeIfPresent(AppBskyEmbedExternal.View.self, forKey: .view)
            } catch {
                // Forward compatibility: a malformed optional field must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'view' — degrading to nil: \(error)")
                view = nil
            }

            do {
                associatedRefs = try container.decodeIfPresent([ComAtprotoRepoStrongRef].self, forKey: .associatedRefs)
            } catch {
                // Forward compatibility: a malformed optional field must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'associatedRefs' — degrading to nil: \(error)")
                associatedRefs = nil
            }

            do {
                associatedRecords = try container.decodeIfPresent([ATProtocolValueContainer].self, forKey: .associatedRecords)
            } catch {
                // Forward compatibility: a malformed optional field must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'associatedRecords' — degrading to nil: \(error)")
                associatedRecords = nil
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(view, forKey: .view)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(associatedRefs, forKey: .associatedRefs)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(associatedRecords, forKey: .associatedRecords)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            if let value = view {
                // Encode optional property even if it's an empty array for CBOR
                let viewValue = try value.toCBORValue()
                map = map.adding(key: "view", value: viewValue)
            }

            if let value = associatedRefs {
                // Encode optional property even if it's an empty array for CBOR
                let associatedRefsValue = try value.toCBORValue()
                map = map.adding(key: "associatedRefs", value: associatedRefsValue)
            }

            if let value = associatedRecords {
                // Encode optional property even if it's an empty array for CBOR
                let associatedRecordsValue = try value.toCBORValue()
                map = map.adding(key: "associatedRecords", value: associatedRecordsValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case view
            case associatedRefs
            case associatedRecords
        }
    }
}

public extension ATProtoClient.App.Bsky.Embed {
    // MARK: - getEmbedExternalView

    /// Resolve one or more AT-URIs into the data needed to render an enhanced external embed. Returns `associatedRefs` (strongRefs to embed into a post's external.associatedRefs), the raw `associatedRecords`, and a hydrated `view`. The response is empty (`{}`) when no records were resolvable, or when validation determined the resolved records don't actually back the requested URL; clients should fall back to their own link-card rendering in that case and skip writing strongRefs to the post.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getEmbedExternalView(input: AppBskyEmbedGetEmbedExternalView.Parameters) async throws -> (responseCode: Int, data: AppBskyEmbedGetEmbedExternalView.Output?) {
        let endpoint = "app.bsky.embed.getEmbedExternalView"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.embed.getEmbedExternalView")
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
                let decodedData = try decoder.decode(AppBskyEmbedGetEmbedExternalView.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.embed.getEmbedExternalView: \(error)")
                return (responseCode, nil)
            }
        } else {
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
