import Foundation

// lexicon: 1, id: app.bsky.richtext.facet

public struct AppBskyRichtextFacet: ATProtocolCodable, ATProtocolValue {
    public static let typeIdentifier = "app.bsky.richtext.facet"
    public let index: ByteSlice
    public let features: [AppBskyRichtextFacetFeaturesUnion]

    public init(index: ByteSlice, features: [AppBskyRichtextFacetFeaturesUnion]) {
        self.index = index
        self.features = features
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        index = try container.decode(ByteSlice.self, forKey: .index)

        features = try container.decode([AppBskyRichtextFacetFeaturesUnion].self, forKey: .features)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(index, forKey: .index)

        try container.encode(features, forKey: .features)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(index)
        hasher.combine(features)
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? Self else { return false }
        if index != other.index {
            return false
        }
        if features != other.features {
            return false
        }
        return true
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.isEqual(to: rhs)
    }

    private enum CodingKeys: String, CodingKey {
        case index
        case features
    }

    public struct Mention: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.richtext.facet#mention"
        public let did: String

        // Standard initializer
        public init(
            did: String
        ) {
            self.did = did
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                did = try container.decode(String.self, forKey: .did)

            } catch {
                LogManager.logError("Decoding error for property 'did': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(did, forKey: .did)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(did)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if did != other.did {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
        }
    }

    public struct Link: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.richtext.facet#link"
        public let uri: URI

        // Standard initializer
        public init(
            uri: URI
        ) {
            self.uri = uri
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                uri = try container.decode(URI.self, forKey: .uri)

            } catch {
                LogManager.logError("Decoding error for property 'uri': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(uri, forKey: .uri)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if uri != other.uri {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
        }
    }

    public struct Tag: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.richtext.facet#tag"
        public let tag: String

        // Standard initializer
        public init(
            tag: String
        ) {
            self.tag = tag
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                tag = try container.decode(String.self, forKey: .tag)

            } catch {
                LogManager.logError("Decoding error for property 'tag': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(tag, forKey: .tag)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(tag)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if tag != other.tag {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case tag
        }
    }

    public struct ByteSlice: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.richtext.facet#byteSlice"
        public let byteStart: Int
        public let byteEnd: Int

        // Standard initializer
        public init(
            byteStart: Int, byteEnd: Int
        ) {
            self.byteStart = byteStart
            self.byteEnd = byteEnd
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                byteStart = try container.decode(Int.self, forKey: .byteStart)

            } catch {
                LogManager.logError("Decoding error for property 'byteStart': \(error)")
                throw error
            }
            do {
                byteEnd = try container.decode(Int.self, forKey: .byteEnd)

            } catch {
                LogManager.logError("Decoding error for property 'byteEnd': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(byteStart, forKey: .byteStart)

            try container.encode(byteEnd, forKey: .byteEnd)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(byteStart)
            hasher.combine(byteEnd)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if byteStart != other.byteStart {
                return false
            }

            if byteEnd != other.byteEnd {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case byteStart
            case byteEnd
        }
    }

    public enum AppBskyRichtextFacetFeaturesUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, PendingDataLoadable {
        case appBskyRichtextFacetMention(AppBskyRichtextFacet.Mention)
        case appBskyRichtextFacetLink(AppBskyRichtextFacet.Link)
        case appBskyRichtextFacetTag(AppBskyRichtextFacet.Tag)
        case unexpected(ATProtocolValueContainer)

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            switch typeValue {
            case "app.bsky.richtext.facet#mention":
                let value = try AppBskyRichtextFacet.Mention(from: decoder)
                self = .appBskyRichtextFacetMention(value)
            case "app.bsky.richtext.facet#link":
                let value = try AppBskyRichtextFacet.Link(from: decoder)
                self = .appBskyRichtextFacetLink(value)
            case "app.bsky.richtext.facet#tag":
                let value = try AppBskyRichtextFacet.Tag(from: decoder)
                self = .appBskyRichtextFacetTag(value)
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .appBskyRichtextFacetMention(value):
                try container.encode("app.bsky.richtext.facet#mention", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyRichtextFacetLink(value):
                try container.encode("app.bsky.richtext.facet#link", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyRichtextFacetTag(value):
                try container.encode("app.bsky.richtext.facet#tag", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .appBskyRichtextFacetMention(value):
                hasher.combine("app.bsky.richtext.facet#mention")
                hasher.combine(value)
            case let .appBskyRichtextFacetLink(value):
                hasher.combine("app.bsky.richtext.facet#link")
                hasher.combine(value)
            case let .appBskyRichtextFacetTag(value):
                hasher.combine("app.bsky.richtext.facet#tag")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
            case rawContent = "_rawContent"
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let otherValue = other as? AppBskyRichtextFacetFeaturesUnion else { return false }

            switch (self, otherValue) {
            case let (
                .appBskyRichtextFacetMention(selfValue),
                .appBskyRichtextFacetMention(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .appBskyRichtextFacetLink(selfValue),
                .appBskyRichtextFacetLink(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .appBskyRichtextFacetTag(selfValue),
                .appBskyRichtextFacetTag(otherValue)
            ):
                return selfValue == otherValue
            case let (.unexpected(selfValue), .unexpected(otherValue)):
                return selfValue.isEqual(to: otherValue)
            default:
                return false
            }
        }
    }

    // Union Array Type

    public struct Features: Codable, ATProtocolCodable, ATProtocolValue {
        public let items: [FeaturesForUnionArray]

        public init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            var items = [FeaturesForUnionArray]()
            while !container.isAtEnd {
                let item = try container.decode(FeaturesForUnionArray.self)
                items.append(item)
            }
            self.items = items
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()
            for item in items {
                try container.encode(item)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if items != other.items {
                return false
            }

            return true
        }
    }

    public enum FeaturesForUnionArray: Codable, ATProtocolCodable, ATProtocolValue {
        case mention(Mention)
        case link(Link)
        case tag(Tag)
        case unexpected(ATProtocolValueContainer)

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            switch typeValue {
            case "Mention":
                let value = try Mention(from: decoder)
                self = .mention(value)
            case "Link":
                let value = try Link(from: decoder)
                self = .link(value)
            case "Tag":
                let value = try Tag(from: decoder)
                self = .tag(value)
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .mention(value):
                try container.encode("Mention", forKey: .type)
                try value.encode(to: encoder)
            case let .link(value):
                try container.encode("Link", forKey: .type)
                try value.encode(to: encoder)
            case let .tag(value):
                try container.encode("Tag", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(ATProtocolValueContainer):
                try ATProtocolValueContainer.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .mention(value):
                hasher.combine("Mention")
                hasher.combine(value)
            case let .link(value):
                hasher.combine("Link")
                hasher.combine(value)
            case let .tag(value):
                hasher.combine("Tag")
                hasher.combine(value)
            case let .unexpected(ATProtocolValueContainer):
                hasher.combine("unexpected")
                hasher.combine(ATProtocolValueContainer)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let otherValue = other as? FeaturesForUnionArray else { return false }

            switch (self, otherValue) {
            case let (
                .mention(selfValue),
                .mention(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .link(selfValue),
                .link(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .tag(selfValue),
                .tag(otherValue)
            ):
                return selfValue == otherValue
            case let (.unexpected(selfValue), .unexpected(otherValue)):
                return selfValue.isEqual(to: otherValue)
            default:
                return false
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }
    }
}
