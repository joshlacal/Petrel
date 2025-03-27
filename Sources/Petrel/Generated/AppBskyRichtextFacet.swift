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

        // MARK: - PendingDataLoadable

        /// Check if any properties contain pending data that needs loading
        public var hasPendingData: Bool {
            var hasPending = false

            if !hasPending, let loadable = did as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            return hasPending
        }

        /// Load any pending data in properties
        public mutating func loadPendingData() async {
            if let loadable = did as? PendingDataLoadable, loadable.hasPendingData {
                var mutableValue = loadable
                await mutableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = mutableValue as? String {
                    did = updatedValue
                }
            }
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

        // MARK: - PendingDataLoadable

        /// Check if any properties contain pending data that needs loading
        public var hasPendingData: Bool {
            var hasPending = false

            if !hasPending, let loadable = uri as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            return hasPending
        }

        /// Load any pending data in properties
        public mutating func loadPendingData() async {
            if let loadable = uri as? PendingDataLoadable, loadable.hasPendingData {
                var mutableValue = loadable
                await mutableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = mutableValue as? URI {
                    uri = updatedValue
                }
            }
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

        // MARK: - PendingDataLoadable

        /// Check if any properties contain pending data that needs loading
        public var hasPendingData: Bool {
            var hasPending = false

            if !hasPending, let loadable = tag as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            return hasPending
        }

        /// Load any pending data in properties
        public mutating func loadPendingData() async {
            if let loadable = tag as? PendingDataLoadable, loadable.hasPendingData {
                var mutableValue = loadable
                await mutableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = mutableValue as? String {
                    tag = updatedValue
                }
            }
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

        // MARK: - PendingDataLoadable

        /// Check if any properties contain pending data that needs loading
        public var hasPendingData: Bool {
            var hasPending = false

            if !hasPending, let loadable = byteStart as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let loadable = byteEnd as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            return hasPending
        }

        /// Load any pending data in properties
        public mutating func loadPendingData() async {
            if let loadable = byteStart as? PendingDataLoadable, loadable.hasPendingData {
                var mutableValue = loadable
                await mutableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = mutableValue as? Int {
                    byteStart = updatedValue
                }
            }

            if let loadable = byteEnd as? PendingDataLoadable, loadable.hasPendingData {
                var mutableValue = loadable
                await mutableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = mutableValue as? Int {
                    byteEnd = updatedValue
                }
            }
        }
    }

    public enum AppBskyRichtextFacetFeaturesUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, PendingDataLoadable, Equatable {
        case appBskyRichtextFacetMention(AppBskyRichtextFacet.Mention)
        case appBskyRichtextFacetLink(AppBskyRichtextFacet.Link)
        case appBskyRichtextFacetTag(AppBskyRichtextFacet.Tag)
        case unexpected(ATProtocolValueContainer)

        public init(_ value: AppBskyRichtextFacet.Mention) {
            self = .appBskyRichtextFacetMention(value)
        }

        public init(_ value: AppBskyRichtextFacet.Link) {
            self = .appBskyRichtextFacetLink(value)
        }

        public init(_ value: AppBskyRichtextFacet.Tag) {
            self = .appBskyRichtextFacetTag(value)
        }

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
        }

        public static func == (lhs: AppBskyRichtextFacetFeaturesUnion, rhs: AppBskyRichtextFacetFeaturesUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .appBskyRichtextFacetMention(lhsValue),
                .appBskyRichtextFacetMention(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyRichtextFacetLink(lhsValue),
                .appBskyRichtextFacetLink(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyRichtextFacetTag(lhsValue),
                .appBskyRichtextFacetTag(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? AppBskyRichtextFacetFeaturesUnion else { return false }
            return self == other
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .appBskyRichtextFacetMention(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .appBskyRichtextFacetLink(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .appBskyRichtextFacetTag(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case let .appBskyRichtextFacetMention(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    await loadable.loadPendingData()
                    // Update the value if it was mutated (only if it's actually the expected type)
                    if let updatedValue = loadable as? AppBskyRichtextFacet.Mention {
                        self = .appBskyRichtextFacetMention(updatedValue)
                    }
                }
            case let .appBskyRichtextFacetLink(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    await loadable.loadPendingData()
                    // Update the value if it was mutated (only if it's actually the expected type)
                    if let updatedValue = loadable as? AppBskyRichtextFacet.Link {
                        self = .appBskyRichtextFacetLink(updatedValue)
                    }
                }
            case let .appBskyRichtextFacetTag(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    await loadable.loadPendingData()
                    // Update the value if it was mutated (only if it's actually the expected type)
                    if let updatedValue = loadable as? AppBskyRichtextFacet.Tag {
                        self = .appBskyRichtextFacetTag(updatedValue)
                    }
                }
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }

    // Union Array Type

    public struct Features: Codable, ATProtocolCodable, ATProtocolValue {
        public let items: [FeaturesForUnionArray]

        public init(items: [FeaturesForUnionArray]) {
            self.items = items
        }

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
        public init(_ value: Mention) {
            self = .mention(value)
        }

        public init(_ value: Link) {
            self = .link(value)
        }

        public init(_ value: Tag) {
            self = .tag(value)
        }

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
