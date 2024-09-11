import Foundation
internal import ZippyJSON

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
                LogManager.logError("Decoding error for property 'indexedAt': \(error)")
                throw error
            }
            do {
                createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)

            } catch {
                LogManager.logError("Decoding error for property 'createdAt': \(error)")
                throw error
            }
            do {
                actor = try container.decode(AppBskyActorDefs.ProfileView.self, forKey: .actor)

            } catch {
                LogManager.logError("Decoding error for property 'actor': \(error)")
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

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case indexedAt
            case createdAt
            case actor
        }
    }

    public struct Parameters: Parametrizable {
        public let uri: ATProtocolURI
        public let cid: String?
        public let limit: Int?
        public let cursor: String?

        public init(
            uri: ATProtocolURI,
            cid: String? = nil,
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

        public let cid: String?

        public let cursor: String?

        public let likes: [Like]

        // Standard public initializer
        public init(
            uri: ATProtocolURI,

            cid: String? = nil,

            cursor: String? = nil,

            likes: [Like]
        ) {
            self.uri = uri

            self.cid = cid

            self.cursor = cursor

            self.likes = likes
        }
    }
}

public extension ATProtoClient.App.Bsky.Feed {
    /// Get like records which reference a subject (by AT-URI and CID).
    func getLikes(input: AppBskyFeedGetLikes.Parameters) async throws -> (responseCode: Int, data: AppBskyFeedGetLikes.Output?) {
        let endpoint = "/app.bsky.feed.getLikes"

        let queryItems = input.asQueryItems()
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: [:],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest, retryCount: 0, duringInitialSetup: false)
        let responseCode = response.statusCode

        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(AppBskyFeedGetLikes.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
