import Foundation

// lexicon: 1, id: app.bsky.feed.post

public struct AppBskyFeedPost: ATProtocolCodable, ATProtocolValue {
    public static let typeIdentifier = "app.bsky.feed.post"
    public let text: String
    public let entities: [Entity]?
    public let facets: [AppBskyRichtextFacet]?
    public let reply: ReplyRef?
    public let embed: AppBskyFeedPostEmbedUnion?
    public let langs: [LanguageCodeContainer]?
    public let labels: AppBskyFeedPostLabelsUnion?
    public let tags: [String]?
    public let createdAt: ATProtocolDate

    // Standard initializer
    public init(text: String, entities: [Entity]?, facets: [AppBskyRichtextFacet]?, reply: ReplyRef?, embed: AppBskyFeedPostEmbedUnion?, langs: [LanguageCodeContainer]?, labels: AppBskyFeedPostLabelsUnion?, tags: [String]?, createdAt: ATProtocolDate) {
        self.text = text

        self.entities = entities

        self.facets = facets

        self.reply = reply

        self.embed = embed

        self.langs = langs

        self.labels = labels

        self.tags = tags

        self.createdAt = createdAt
    }

    // Codable initializer
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        text = try container.decode(String.self, forKey: .text)

        entities = try container.decodeIfPresent([Entity].self, forKey: .entities)

        facets = try container.decodeIfPresent([AppBskyRichtextFacet].self, forKey: .facets)

        reply = try container.decodeIfPresent(ReplyRef.self, forKey: .reply)

        embed = try container.decodeIfPresent(AppBskyFeedPostEmbedUnion.self, forKey: .embed)

        langs = try container.decodeIfPresent([LanguageCodeContainer].self, forKey: .langs)

        labels = try container.decodeIfPresent(AppBskyFeedPostLabelsUnion.self, forKey: .labels)

        tags = try container.decodeIfPresent([String].self, forKey: .tags)

        createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Encode the $type field
        try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

        try container.encode(text, forKey: .text)

        if let value = entities {
            try container.encode(value, forKey: .entities)
        }

        if let value = facets {
            try container.encode(value, forKey: .facets)
        }

        if let value = reply {
            try container.encode(value, forKey: .reply)
        }

        if let value = embed {
            try container.encode(value, forKey: .embed)
        }

        if let value = langs {
            try container.encode(value, forKey: .langs)
        }

        if let value = labels {
            try container.encode(value, forKey: .labels)
        }

        if let value = tags {
            try container.encode(value, forKey: .tags)
        }

        try container.encode(createdAt, forKey: .createdAt)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.isEqual(to: rhs)
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? Self else { return false }

        if text != other.text {
            return false
        }

        if entities != other.entities {
            return false
        }

        if facets != other.facets {
            return false
        }

        if reply != other.reply {
            return false
        }

        if embed != other.embed {
            return false
        }

        if langs != other.langs {
            return false
        }

        if labels != other.labels {
            return false
        }

        if tags != other.tags {
            return false
        }

        if createdAt != other.createdAt {
            return false
        }

        return true
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(text)
        if let value = entities {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?) // Placeholder for nil
        }
        if let value = facets {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?) // Placeholder for nil
        }
        if let value = reply {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?) // Placeholder for nil
        }
        if let value = embed {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?) // Placeholder for nil
        }
        if let value = langs {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?) // Placeholder for nil
        }
        if let value = labels {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?) // Placeholder for nil
        }
        if let value = tags {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?) // Placeholder for nil
        }
        hasher.combine(createdAt)
    }

    private enum CodingKeys: String, CodingKey {
        case typeIdentifier = "$type"
        case text
        case entities
        case facets
        case reply
        case embed
        case langs
        case labels
        case tags
        case createdAt
    }

    public struct ReplyRef: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.feed.post#replyRef"
        public let root: ComAtprotoRepoStrongRef
        public let parent: ComAtprotoRepoStrongRef

        // Standard initializer
        public init(
            root: ComAtprotoRepoStrongRef, parent: ComAtprotoRepoStrongRef
        ) {
            self.root = root
            self.parent = parent
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                root = try container.decode(ComAtprotoRepoStrongRef.self, forKey: .root)

            } catch {
                LogManager.logError("Decoding error for property 'root': \(error)")
                throw error
            }
            do {
                parent = try container.decode(ComAtprotoRepoStrongRef.self, forKey: .parent)

            } catch {
                LogManager.logError("Decoding error for property 'parent': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(root, forKey: .root)

            try container.encode(parent, forKey: .parent)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(root)
            hasher.combine(parent)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if root != other.root {
                return false
            }

            if parent != other.parent {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case root
            case parent
        }
    }

    public struct Entity: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.feed.post#entity"
        public let index: TextSlice
        public let type: String
        public let value: String

        // Standard initializer
        public init(
            index: TextSlice, type: String, value: String
        ) {
            self.index = index
            self.type = type
            self.value = value
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                index = try container.decode(TextSlice.self, forKey: .index)

            } catch {
                LogManager.logError("Decoding error for property 'index': \(error)")
                throw error
            }
            do {
                type = try container.decode(String.self, forKey: .type)

            } catch {
                LogManager.logError("Decoding error for property 'type': \(error)")
                throw error
            }
            do {
                value = try container.decode(String.self, forKey: .value)

            } catch {
                LogManager.logError("Decoding error for property 'value': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(index, forKey: .index)

            try container.encode(type, forKey: .type)

            try container.encode(value, forKey: .value)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(index)
            hasher.combine(type)
            hasher.combine(value)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if index != other.index {
                return false
            }

            if type != other.type {
                return false
            }

            if value != other.value {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case index
            case type
            case value
        }
    }

    public struct TextSlice: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.feed.post#textSlice"
        public let start: Int
        public let end: Int

        // Standard initializer
        public init(
            start: Int, end: Int
        ) {
            self.start = start
            self.end = end
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                start = try container.decode(Int.self, forKey: .start)

            } catch {
                LogManager.logError("Decoding error for property 'start': \(error)")
                throw error
            }
            do {
                end = try container.decode(Int.self, forKey: .end)

            } catch {
                LogManager.logError("Decoding error for property 'end': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(start, forKey: .start)

            try container.encode(end, forKey: .end)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(start)
            hasher.combine(end)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if start != other.start {
                return false
            }

            if end != other.end {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case start
            case end
        }
    }

    public enum AppBskyFeedPostEmbedUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, PendingDataLoadable, Equatable {
        case appBskyEmbedImages(AppBskyEmbedImages)
        case appBskyEmbedVideo(AppBskyEmbedVideo)
        case appBskyEmbedExternal(AppBskyEmbedExternal)
        case appBskyEmbedRecord(AppBskyEmbedRecord)
        case appBskyEmbedRecordWithMedia(AppBskyEmbedRecordWithMedia)
        case unexpected(ATProtocolValueContainer)

        public static func appBskyEmbedImages(_ value: AppBskyEmbedImages) -> AppBskyFeedPostEmbedUnion {
            return .appBskyEmbedImages(value)
        }

        public static func appBskyEmbedVideo(_ value: AppBskyEmbedVideo) -> AppBskyFeedPostEmbedUnion {
            return .appBskyEmbedVideo(value)
        }

        public static func appBskyEmbedExternal(_ value: AppBskyEmbedExternal) -> AppBskyFeedPostEmbedUnion {
            return .appBskyEmbedExternal(value)
        }

        public static func appBskyEmbedRecord(_ value: AppBskyEmbedRecord) -> AppBskyFeedPostEmbedUnion {
            return .appBskyEmbedRecord(value)
        }

        public static func appBskyEmbedRecordWithMedia(_ value: AppBskyEmbedRecordWithMedia) -> AppBskyFeedPostEmbedUnion {
            return .appBskyEmbedRecordWithMedia(value)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            switch typeValue {
            case "app.bsky.embed.images":
                let value = try AppBskyEmbedImages(from: decoder)
                self = .appBskyEmbedImages(value)
            case "app.bsky.embed.video":
                let value = try AppBskyEmbedVideo(from: decoder)
                self = .appBskyEmbedVideo(value)
            case "app.bsky.embed.external":
                let value = try AppBskyEmbedExternal(from: decoder)
                self = .appBskyEmbedExternal(value)
            case "app.bsky.embed.record":
                let value = try AppBskyEmbedRecord(from: decoder)
                self = .appBskyEmbedRecord(value)
            case "app.bsky.embed.recordWithMedia":
                let value = try AppBskyEmbedRecordWithMedia(from: decoder)
                self = .appBskyEmbedRecordWithMedia(value)
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .appBskyEmbedImages(value):
                try container.encode("app.bsky.embed.images", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyEmbedVideo(value):
                try container.encode("app.bsky.embed.video", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyEmbedExternal(value):
                try container.encode("app.bsky.embed.external", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyEmbedRecord(value):
                try container.encode("app.bsky.embed.record", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyEmbedRecordWithMedia(value):
                try container.encode("app.bsky.embed.recordWithMedia", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .appBskyEmbedImages(value):
                hasher.combine("app.bsky.embed.images")
                hasher.combine(value)
            case let .appBskyEmbedVideo(value):
                hasher.combine("app.bsky.embed.video")
                hasher.combine(value)
            case let .appBskyEmbedExternal(value):
                hasher.combine("app.bsky.embed.external")
                hasher.combine(value)
            case let .appBskyEmbedRecord(value):
                hasher.combine("app.bsky.embed.record")
                hasher.combine(value)
            case let .appBskyEmbedRecordWithMedia(value):
                hasher.combine("app.bsky.embed.recordWithMedia")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: AppBskyFeedPostEmbedUnion, rhs: AppBskyFeedPostEmbedUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .appBskyEmbedImages(lhsValue),
                .appBskyEmbedImages(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyEmbedVideo(lhsValue),
                .appBskyEmbedVideo(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyEmbedExternal(lhsValue),
                .appBskyEmbedExternal(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyEmbedRecord(lhsValue),
                .appBskyEmbedRecord(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyEmbedRecordWithMedia(lhsValue),
                .appBskyEmbedRecordWithMedia(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? AppBskyFeedPostEmbedUnion else { return false }
            return self == other
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .appBskyEmbedImages(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .appBskyEmbedVideo(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .appBskyEmbedExternal(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .appBskyEmbedRecord(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .appBskyEmbedRecordWithMedia(value):
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
            case var .appBskyEmbedImages(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? AppBskyEmbedImages {
                            self = .appBskyEmbedImages(updatedValue)
                        }
                    }
                }
            case var .appBskyEmbedVideo(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? AppBskyEmbedVideo {
                            self = .appBskyEmbedVideo(updatedValue)
                        }
                    }
                }
            case var .appBskyEmbedExternal(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? AppBskyEmbedExternal {
                            self = .appBskyEmbedExternal(updatedValue)
                        }
                    }
                }
            case var .appBskyEmbedRecord(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? AppBskyEmbedRecord {
                            self = .appBskyEmbedRecord(updatedValue)
                        }
                    }
                }
            case var .appBskyEmbedRecordWithMedia(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? AppBskyEmbedRecordWithMedia {
                            self = .appBskyEmbedRecordWithMedia(updatedValue)
                        }
                    }
                }
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }

    public enum AppBskyFeedPostLabelsUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, PendingDataLoadable, Equatable {
        case comAtprotoLabelDefsSelfLabels(ComAtprotoLabelDefs.SelfLabels)
        case unexpected(ATProtocolValueContainer)

        public static func comAtprotoLabelDefsSelfLabels(_ value: ComAtprotoLabelDefs.SelfLabels) -> AppBskyFeedPostLabelsUnion {
            return .comAtprotoLabelDefsSelfLabels(value)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            switch typeValue {
            case "com.atproto.label.defs#selfLabels":
                let value = try ComAtprotoLabelDefs.SelfLabels(from: decoder)
                self = .comAtprotoLabelDefsSelfLabels(value)
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .comAtprotoLabelDefsSelfLabels(value):
                try container.encode("com.atproto.label.defs#selfLabels", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .comAtprotoLabelDefsSelfLabels(value):
                hasher.combine("com.atproto.label.defs#selfLabels")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: AppBskyFeedPostLabelsUnion, rhs: AppBskyFeedPostLabelsUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .comAtprotoLabelDefsSelfLabels(lhsValue),
                .comAtprotoLabelDefsSelfLabels(rhsValue)
            ):
                return lhsValue == rhsValue

            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)

            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? AppBskyFeedPostLabelsUnion else { return false }
            return self == other
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .comAtprotoLabelDefsSelfLabels(value):
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
            case var .comAtprotoLabelDefsSelfLabels(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? ComAtprotoLabelDefs.SelfLabels {
                            self = .comAtprotoLabelDefsSelfLabels(updatedValue)
                        }
                    }
                }
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }
}
