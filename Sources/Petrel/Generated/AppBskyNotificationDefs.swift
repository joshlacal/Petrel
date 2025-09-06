import Foundation

// lexicon: 1, id: app.bsky.notification.defs

public enum AppBskyNotificationDefs {
    public static let typeIdentifier = "app.bsky.notification.defs"

    public struct RecordDeleted: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.notification.defs#recordDeleted"

        // Standard initializer
        public init(
        ) {}

        // Codable initializer
        public init(from decoder: Decoder) throws {
            _ = decoder // Acknowledge parameter for empty struct
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
        }

        public func hash(into hasher: inout Hasher) {}

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            return other is Self // For empty structs, just check the type
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
        }
    }

    public struct ChatPreference: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.notification.defs#chatPreference"
        public let include: String
        public let push: Bool

        // Standard initializer
        public init(
            include: String, push: Bool
        ) {
            self.include = include
            self.push = push
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                include = try container.decode(String.self, forKey: .include)

            } catch {
                LogManager.logError("Decoding error for property 'include': \(error)")
                throw error
            }
            do {
                push = try container.decode(Bool.self, forKey: .push)

            } catch {
                LogManager.logError("Decoding error for property 'push': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(include, forKey: .include)

            try container.encode(push, forKey: .push)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(include)
            hasher.combine(push)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if include != other.include {
                return false
            }

            if push != other.push {
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

            let includeValue = try include.toCBORValue()
            map = map.adding(key: "include", value: includeValue)

            let pushValue = try push.toCBORValue()
            map = map.adding(key: "push", value: pushValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case include
            case push
        }
    }

    public struct FilterablePreference: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.notification.defs#filterablePreference"
        public let include: String
        public let list: Bool
        public let push: Bool

        // Standard initializer
        public init(
            include: String, list: Bool, push: Bool
        ) {
            self.include = include
            self.list = list
            self.push = push
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                include = try container.decode(String.self, forKey: .include)

            } catch {
                LogManager.logError("Decoding error for property 'include': \(error)")
                throw error
            }
            do {
                list = try container.decode(Bool.self, forKey: .list)

            } catch {
                LogManager.logError("Decoding error for property 'list': \(error)")
                throw error
            }
            do {
                push = try container.decode(Bool.self, forKey: .push)

            } catch {
                LogManager.logError("Decoding error for property 'push': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(include, forKey: .include)

            try container.encode(list, forKey: .list)

            try container.encode(push, forKey: .push)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(include)
            hasher.combine(list)
            hasher.combine(push)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if include != other.include {
                return false
            }

            if list != other.list {
                return false
            }

            if push != other.push {
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

            let includeValue = try include.toCBORValue()
            map = map.adding(key: "include", value: includeValue)

            let listValue = try list.toCBORValue()
            map = map.adding(key: "list", value: listValue)

            let pushValue = try push.toCBORValue()
            map = map.adding(key: "push", value: pushValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case include
            case list
            case push
        }
    }

    public struct Preference: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.notification.defs#preference"
        public let list: Bool
        public let push: Bool

        // Standard initializer
        public init(
            list: Bool, push: Bool
        ) {
            self.list = list
            self.push = push
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                list = try container.decode(Bool.self, forKey: .list)

            } catch {
                LogManager.logError("Decoding error for property 'list': \(error)")
                throw error
            }
            do {
                push = try container.decode(Bool.self, forKey: .push)

            } catch {
                LogManager.logError("Decoding error for property 'push': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(list, forKey: .list)

            try container.encode(push, forKey: .push)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(list)
            hasher.combine(push)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if list != other.list {
                return false
            }

            if push != other.push {
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

            let listValue = try list.toCBORValue()
            map = map.adding(key: "list", value: listValue)

            let pushValue = try push.toCBORValue()
            map = map.adding(key: "push", value: pushValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case list
            case push
        }
    }

    public struct Preferences: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.notification.defs#preferences"
        public let chat: ChatPreference
        public let follow: FilterablePreference
        public let like: FilterablePreference
        public let likeViaRepost: FilterablePreference
        public let mention: FilterablePreference
        public let quote: FilterablePreference
        public let reply: FilterablePreference
        public let repost: FilterablePreference
        public let repostViaRepost: FilterablePreference
        public let starterpackJoined: Preference
        public let subscribedPost: Preference
        public let unverified: Preference
        public let verified: Preference

        // Standard initializer
        public init(
            chat: ChatPreference, follow: FilterablePreference, like: FilterablePreference, likeViaRepost: FilterablePreference, mention: FilterablePreference, quote: FilterablePreference, reply: FilterablePreference, repost: FilterablePreference, repostViaRepost: FilterablePreference, starterpackJoined: Preference, subscribedPost: Preference, unverified: Preference, verified: Preference
        ) {
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

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                chat = try container.decode(ChatPreference.self, forKey: .chat)

            } catch {
                LogManager.logError("Decoding error for property 'chat': \(error)")
                throw error
            }
            do {
                follow = try container.decode(FilterablePreference.self, forKey: .follow)

            } catch {
                LogManager.logError("Decoding error for property 'follow': \(error)")
                throw error
            }
            do {
                like = try container.decode(FilterablePreference.self, forKey: .like)

            } catch {
                LogManager.logError("Decoding error for property 'like': \(error)")
                throw error
            }
            do {
                likeViaRepost = try container.decode(FilterablePreference.self, forKey: .likeViaRepost)

            } catch {
                LogManager.logError("Decoding error for property 'likeViaRepost': \(error)")
                throw error
            }
            do {
                mention = try container.decode(FilterablePreference.self, forKey: .mention)

            } catch {
                LogManager.logError("Decoding error for property 'mention': \(error)")
                throw error
            }
            do {
                quote = try container.decode(FilterablePreference.self, forKey: .quote)

            } catch {
                LogManager.logError("Decoding error for property 'quote': \(error)")
                throw error
            }
            do {
                reply = try container.decode(FilterablePreference.self, forKey: .reply)

            } catch {
                LogManager.logError("Decoding error for property 'reply': \(error)")
                throw error
            }
            do {
                repost = try container.decode(FilterablePreference.self, forKey: .repost)

            } catch {
                LogManager.logError("Decoding error for property 'repost': \(error)")
                throw error
            }
            do {
                repostViaRepost = try container.decode(FilterablePreference.self, forKey: .repostViaRepost)

            } catch {
                LogManager.logError("Decoding error for property 'repostViaRepost': \(error)")
                throw error
            }
            do {
                starterpackJoined = try container.decode(Preference.self, forKey: .starterpackJoined)

            } catch {
                LogManager.logError("Decoding error for property 'starterpackJoined': \(error)")
                throw error
            }
            do {
                subscribedPost = try container.decode(Preference.self, forKey: .subscribedPost)

            } catch {
                LogManager.logError("Decoding error for property 'subscribedPost': \(error)")
                throw error
            }
            do {
                unverified = try container.decode(Preference.self, forKey: .unverified)

            } catch {
                LogManager.logError("Decoding error for property 'unverified': \(error)")
                throw error
            }
            do {
                verified = try container.decode(Preference.self, forKey: .verified)

            } catch {
                LogManager.logError("Decoding error for property 'verified': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(chat, forKey: .chat)

            try container.encode(follow, forKey: .follow)

            try container.encode(like, forKey: .like)

            try container.encode(likeViaRepost, forKey: .likeViaRepost)

            try container.encode(mention, forKey: .mention)

            try container.encode(quote, forKey: .quote)

            try container.encode(reply, forKey: .reply)

            try container.encode(repost, forKey: .repost)

            try container.encode(repostViaRepost, forKey: .repostViaRepost)

            try container.encode(starterpackJoined, forKey: .starterpackJoined)

            try container.encode(subscribedPost, forKey: .subscribedPost)

            try container.encode(unverified, forKey: .unverified)

            try container.encode(verified, forKey: .verified)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(chat)
            hasher.combine(follow)
            hasher.combine(like)
            hasher.combine(likeViaRepost)
            hasher.combine(mention)
            hasher.combine(quote)
            hasher.combine(reply)
            hasher.combine(repost)
            hasher.combine(repostViaRepost)
            hasher.combine(starterpackJoined)
            hasher.combine(subscribedPost)
            hasher.combine(unverified)
            hasher.combine(verified)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if chat != other.chat {
                return false
            }

            if follow != other.follow {
                return false
            }

            if like != other.like {
                return false
            }

            if likeViaRepost != other.likeViaRepost {
                return false
            }

            if mention != other.mention {
                return false
            }

            if quote != other.quote {
                return false
            }

            if reply != other.reply {
                return false
            }

            if repost != other.repost {
                return false
            }

            if repostViaRepost != other.repostViaRepost {
                return false
            }

            if starterpackJoined != other.starterpackJoined {
                return false
            }

            if subscribedPost != other.subscribedPost {
                return false
            }

            if unverified != other.unverified {
                return false
            }

            if verified != other.verified {
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

            let chatValue = try chat.toCBORValue()
            map = map.adding(key: "chat", value: chatValue)

            let followValue = try follow.toCBORValue()
            map = map.adding(key: "follow", value: followValue)

            let likeValue = try like.toCBORValue()
            map = map.adding(key: "like", value: likeValue)

            let likeViaRepostValue = try likeViaRepost.toCBORValue()
            map = map.adding(key: "likeViaRepost", value: likeViaRepostValue)

            let mentionValue = try mention.toCBORValue()
            map = map.adding(key: "mention", value: mentionValue)

            let quoteValue = try quote.toCBORValue()
            map = map.adding(key: "quote", value: quoteValue)

            let replyValue = try reply.toCBORValue()
            map = map.adding(key: "reply", value: replyValue)

            let repostValue = try repost.toCBORValue()
            map = map.adding(key: "repost", value: repostValue)

            let repostViaRepostValue = try repostViaRepost.toCBORValue()
            map = map.adding(key: "repostViaRepost", value: repostViaRepostValue)

            let starterpackJoinedValue = try starterpackJoined.toCBORValue()
            map = map.adding(key: "starterpackJoined", value: starterpackJoinedValue)

            let subscribedPostValue = try subscribedPost.toCBORValue()
            map = map.adding(key: "subscribedPost", value: subscribedPostValue)

            let unverifiedValue = try unverified.toCBORValue()
            map = map.adding(key: "unverified", value: unverifiedValue)

            let verifiedValue = try verified.toCBORValue()
            map = map.adding(key: "verified", value: verifiedValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
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
    }

    public struct ActivitySubscription: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.notification.defs#activitySubscription"
        public let post: Bool
        public let reply: Bool

        // Standard initializer
        public init(
            post: Bool, reply: Bool
        ) {
            self.post = post
            self.reply = reply
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                post = try container.decode(Bool.self, forKey: .post)

            } catch {
                LogManager.logError("Decoding error for property 'post': \(error)")
                throw error
            }
            do {
                reply = try container.decode(Bool.self, forKey: .reply)

            } catch {
                LogManager.logError("Decoding error for property 'reply': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(post, forKey: .post)

            try container.encode(reply, forKey: .reply)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(post)
            hasher.combine(reply)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if post != other.post {
                return false
            }

            if reply != other.reply {
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

            let postValue = try post.toCBORValue()
            map = map.adding(key: "post", value: postValue)

            let replyValue = try reply.toCBORValue()
            map = map.adding(key: "reply", value: replyValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case post
            case reply
        }
    }

    public struct SubjectActivitySubscription: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.notification.defs#subjectActivitySubscription"
        public let subject: DID
        public let activitySubscription: ActivitySubscription

        // Standard initializer
        public init(
            subject: DID, activitySubscription: ActivitySubscription
        ) {
            self.subject = subject
            self.activitySubscription = activitySubscription
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                subject = try container.decode(DID.self, forKey: .subject)

            } catch {
                LogManager.logError("Decoding error for property 'subject': \(error)")
                throw error
            }
            do {
                activitySubscription = try container.decode(ActivitySubscription.self, forKey: .activitySubscription)

            } catch {
                LogManager.logError("Decoding error for property 'activitySubscription': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(subject, forKey: .subject)

            try container.encode(activitySubscription, forKey: .activitySubscription)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(subject)
            hasher.combine(activitySubscription)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if subject != other.subject {
                return false
            }

            if activitySubscription != other.activitySubscription {
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

            let subjectValue = try subject.toCBORValue()
            map = map.adding(key: "subject", value: subjectValue)

            let activitySubscriptionValue = try activitySubscription.toCBORValue()
            map = map.adding(key: "activitySubscription", value: activitySubscriptionValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case subject
            case activitySubscription
        }
    }
}
