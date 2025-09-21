import Foundation

// lexicon: 1, id: app.bsky.notification.putPreferencesV2

public enum AppBskyNotificationPutPreferencesV2 {
    public static let typeIdentifier = "app.bsky.notification.putPreferencesV2"
    public struct Input: ATProtocolCodable {
        public let chat: AppBskyNotificationDefs.ChatPreference?
        public let follow: AppBskyNotificationDefs.FilterablePreference?
        public let like: AppBskyNotificationDefs.FilterablePreference?
        public let likeViaRepost: AppBskyNotificationDefs.FilterablePreference?
        public let mention: AppBskyNotificationDefs.FilterablePreference?
        public let quote: AppBskyNotificationDefs.FilterablePreference?
        public let reply: AppBskyNotificationDefs.FilterablePreference?
        public let repost: AppBskyNotificationDefs.FilterablePreference?
        public let repostViaRepost: AppBskyNotificationDefs.FilterablePreference?
        public let starterpackJoined: AppBskyNotificationDefs.Preference?
        public let subscribedPost: AppBskyNotificationDefs.Preference?
        public let unverified: AppBskyNotificationDefs.Preference?
        public let verified: AppBskyNotificationDefs.Preference?

        // Standard public initializer
        public init(chat: AppBskyNotificationDefs.ChatPreference? = nil, follow: AppBskyNotificationDefs.FilterablePreference? = nil, like: AppBskyNotificationDefs.FilterablePreference? = nil, likeViaRepost: AppBskyNotificationDefs.FilterablePreference? = nil, mention: AppBskyNotificationDefs.FilterablePreference? = nil, quote: AppBskyNotificationDefs.FilterablePreference? = nil, reply: AppBskyNotificationDefs.FilterablePreference? = nil, repost: AppBskyNotificationDefs.FilterablePreference? = nil, repostViaRepost: AppBskyNotificationDefs.FilterablePreference? = nil, starterpackJoined: AppBskyNotificationDefs.Preference? = nil, subscribedPost: AppBskyNotificationDefs.Preference? = nil, unverified: AppBskyNotificationDefs.Preference? = nil, verified: AppBskyNotificationDefs.Preference? = nil) {
            self.chat = chat
            self.follow = follow
            self.like = like
            self.likeViaRepost = likeViaRepost
            self.mention = mention
            self.quote = quote
            self.reply = reply
            self.repost = repost
            self.repostViaRepost = repostViaRepost
            self.starterpackJoined = starterpackJoined
            self.subscribedPost = subscribedPost
            self.unverified = unverified
            self.verified = verified
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            chat = try container.decodeIfPresent(AppBskyNotificationDefs.ChatPreference.self, forKey: .chat)

            follow = try container.decodeIfPresent(AppBskyNotificationDefs.FilterablePreference.self, forKey: .follow)

            like = try container.decodeIfPresent(AppBskyNotificationDefs.FilterablePreference.self, forKey: .like)

            likeViaRepost = try container.decodeIfPresent(AppBskyNotificationDefs.FilterablePreference.self, forKey: .likeViaRepost)

            mention = try container.decodeIfPresent(AppBskyNotificationDefs.FilterablePreference.self, forKey: .mention)

            quote = try container.decodeIfPresent(AppBskyNotificationDefs.FilterablePreference.self, forKey: .quote)

            reply = try container.decodeIfPresent(AppBskyNotificationDefs.FilterablePreference.self, forKey: .reply)

            repost = try container.decodeIfPresent(AppBskyNotificationDefs.FilterablePreference.self, forKey: .repost)

            repostViaRepost = try container.decodeIfPresent(AppBskyNotificationDefs.FilterablePreference.self, forKey: .repostViaRepost)

            starterpackJoined = try container.decodeIfPresent(AppBskyNotificationDefs.Preference.self, forKey: .starterpackJoined)

            subscribedPost = try container.decodeIfPresent(AppBskyNotificationDefs.Preference.self, forKey: .subscribedPost)

            unverified = try container.decodeIfPresent(AppBskyNotificationDefs.Preference.self, forKey: .unverified)

            verified = try container.decodeIfPresent(AppBskyNotificationDefs.Preference.self, forKey: .verified)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(chat, forKey: .chat)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(follow, forKey: .follow)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(like, forKey: .like)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(likeViaRepost, forKey: .likeViaRepost)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(mention, forKey: .mention)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(quote, forKey: .quote)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(reply, forKey: .reply)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(repost, forKey: .repost)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(repostViaRepost, forKey: .repostViaRepost)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(starterpackJoined, forKey: .starterpackJoined)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(subscribedPost, forKey: .subscribedPost)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(unverified, forKey: .unverified)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(verified, forKey: .verified)
        }

        private enum CodingKeys: String, CodingKey {
            case chat
            case follow
            case like
            case likeViaRepost
            case mention
            case quote
            case reply
            case repost
            case repostViaRepost
            case starterpackJoined
            case subscribedPost
            case unverified
            case verified
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            if let value = chat {
                // Encode optional property even if it's an empty array for CBOR
                let chatValue = try value.toCBORValue()
                map = map.adding(key: "chat", value: chatValue)
            }

            if let value = follow {
                // Encode optional property even if it's an empty array for CBOR
                let followValue = try value.toCBORValue()
                map = map.adding(key: "follow", value: followValue)
            }

            if let value = like {
                // Encode optional property even if it's an empty array for CBOR
                let likeValue = try value.toCBORValue()
                map = map.adding(key: "like", value: likeValue)
            }

            if let value = likeViaRepost {
                // Encode optional property even if it's an empty array for CBOR
                let likeViaRepostValue = try value.toCBORValue()
                map = map.adding(key: "likeViaRepost", value: likeViaRepostValue)
            }

            if let value = mention {
                // Encode optional property even if it's an empty array for CBOR
                let mentionValue = try value.toCBORValue()
                map = map.adding(key: "mention", value: mentionValue)
            }

            if let value = quote {
                // Encode optional property even if it's an empty array for CBOR
                let quoteValue = try value.toCBORValue()
                map = map.adding(key: "quote", value: quoteValue)
            }

            if let value = reply {
                // Encode optional property even if it's an empty array for CBOR
                let replyValue = try value.toCBORValue()
                map = map.adding(key: "reply", value: replyValue)
            }

            if let value = repost {
                // Encode optional property even if it's an empty array for CBOR
                let repostValue = try value.toCBORValue()
                map = map.adding(key: "repost", value: repostValue)
            }

            if let value = repostViaRepost {
                // Encode optional property even if it's an empty array for CBOR
                let repostViaRepostValue = try value.toCBORValue()
                map = map.adding(key: "repostViaRepost", value: repostViaRepostValue)
            }

            if let value = starterpackJoined {
                // Encode optional property even if it's an empty array for CBOR
                let starterpackJoinedValue = try value.toCBORValue()
                map = map.adding(key: "starterpackJoined", value: starterpackJoinedValue)
            }

            if let value = subscribedPost {
                // Encode optional property even if it's an empty array for CBOR
                let subscribedPostValue = try value.toCBORValue()
                map = map.adding(key: "subscribedPost", value: subscribedPostValue)
            }

            if let value = unverified {
                // Encode optional property even if it's an empty array for CBOR
                let unverifiedValue = try value.toCBORValue()
                map = map.adding(key: "unverified", value: unverifiedValue)
            }

            if let value = verified {
                // Encode optional property even if it's an empty array for CBOR
                let verifiedValue = try value.toCBORValue()
                map = map.adding(key: "verified", value: verifiedValue)
            }

            return map
        }
    }

    public struct Output: ATProtocolCodable {
        public let preferences: AppBskyNotificationDefs.Preferences

        // Standard public initializer
        public init(
            preferences: AppBskyNotificationDefs.Preferences

        ) {
            self.preferences = preferences
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            preferences = try container.decode(AppBskyNotificationDefs.Preferences.self, forKey: .preferences)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(preferences, forKey: .preferences)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let preferencesValue = try preferences.toCBORValue()
            map = map.adding(key: "preferences", value: preferencesValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case preferences
        }
    }
}

public extension ATProtoClient.App.Bsky.Notification {
    // MARK: - putPreferencesV2

    /// Set notification-related preferences for an account. Requires auth.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func putPreferencesV2(
        input: AppBskyNotificationPutPreferencesV2.Input

    ) async throws -> (responseCode: Int, data: AppBskyNotificationPutPreferencesV2.Output?) {
        let endpoint = "app.bsky.notification.putPreferencesV2"

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

        let (responseData, response) = try await networkService.performRequest(urlRequest)

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
                let decodedData = try decoder.decode(AppBskyNotificationPutPreferencesV2.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.notification.putPreferencesV2: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
