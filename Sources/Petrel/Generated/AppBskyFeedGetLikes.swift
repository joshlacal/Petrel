import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// lexicon: 1, id: app.bsky.feed.getLikes

public enum AppBskyFeedGetLikes {
    public static let typeIdentifier = "app.bsky.feed.getLikes"

    public struct Like: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.feed.getLikes#like"
        public let indexedAt: ATProtocolDate
        public let createdAt: ATProtocolDate
        public let actor: AppBskyActorDefs.ProfileView

        // Standard initializer
        public init(
            indexedAt: ATProtocolDate, createdAt: ATProtocolDate, actor: AppBskyActorDefs.ProfileView
        ) {
            self.indexedAt = indexedAt
            self.createdAt = createdAt
            self.actor = actor
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                indexedAt = try container.decode(ATProtocolDate.self, forKey: .indexedAt)

            } catch {
                LogManager.logError("Decoding error for required property 'indexedAt': \(error)")

                throw error
            }
            do {
                createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)

            } catch {
                LogManager.logError("Decoding error for required property 'createdAt': \(error)")

                throw error
            }
            do {
                actor = try container.decode(AppBskyActorDefs.ProfileView.self, forKey: .actor)

            } catch {
                LogManager.logError("Decoding error for required property 'actor': \(error)")

                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(indexedAt, forKey: .indexedAt)

            try container.encode(createdAt, forKey: .createdAt)

            try container.encode(actor, forKey: .actor)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(indexedAt)
            hasher.combine(createdAt)
            hasher.combine(actor)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if indexedAt != other.indexedAt {
                return false
            }

            if createdAt != other.createdAt {
                return false
            }

            if actor != other.actor {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let indexedAtValue = try indexedAt.toCBORValue()
            map = map.adding(key: "indexedAt", value: indexedAtValue)

            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)

            let actorValue = try actor.toCBORValue()
            map = map.adding(key: "actor", value: actorValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case indexedAt
            case createdAt
            case actor
        }
    }

    public struct Parameters: Parametrizable {
        public let uri: ATProtocolURI
        public let cid: CID?
        public let limit: Int?
        public let cursor: String?

        public init(
            uri: ATProtocolURI,
            cid: CID? = nil,
            limit: Int? = nil,
            cursor: String? = nil
        ) {
            self.uri = uri
            self.cid = cid
            self.limit = limit
            self.cursor = cursor
        }
    }

    public struct Output: ATProtocolCodable {
        public let uri: ATProtocolURI

        public let cid: CID?

        public let cursor: String?

        public let likes: [Like]

        // Standard public initializer
        public init(
            uri: ATProtocolURI,

            cid: CID? = nil,

            cursor: String? = nil,

            likes: [Like]

        ) {
            self.uri = uri

            self.cid = cid

            self.cursor = cursor

            self.likes = likes
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            uri = try container.decode(ATProtocolURI.self, forKey: .uri)

            cid = try container.decodeIfPresent(CID.self, forKey: .cid)

            cursor = try container.decodeIfPresent(String.self, forKey: .cursor)

            likes = try container.decode([Like].self, forKey: .likes)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(uri, forKey: .uri)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cid, forKey: .cid)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)

            try container.encode(likes, forKey: .likes)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let uriValue = try uri.toCBORValue()
            map = map.adding(key: "uri", value: uriValue)

            if let value = cid {
                // Encode optional property even if it's an empty array for CBOR
                let cidValue = try value.toCBORValue()
                map = map.adding(key: "cid", value: cidValue)
            }

            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR
                let cursorValue = try value.toCBORValue()
                map = map.adding(key: "cursor", value: cursorValue)
            }

            let likesValue = try likes.toCBORValue()
            map = map.adding(key: "likes", value: likesValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case uri
            case cid
            case cursor
            case likes
        }
    }
}

public extension ATProtoClient.App.Bsky.Feed {
    // MARK: - getLikes

    /// Get like records which reference a subject (by AT-URI and CID).
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getLikes(input: AppBskyFeedGetLikes.Parameters) async throws -> (responseCode: Int, data: AppBskyFeedGetLikes.Output?) {
        let endpoint = "app.bsky.feed.getLikes"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.feed.getLikes")
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
                let decodedData = try decoder.decode(AppBskyFeedGetLikes.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.feed.getLikes: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
