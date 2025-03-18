import Foundation

// lexicon: 1, id: app.bsky.embed.recordWithMedia

public struct AppBskyEmbedRecordWithMedia: ATProtocolCodable, ATProtocolValue {
    public static let typeIdentifier = "app.bsky.embed.recordWithMedia"
    public let record: AppBskyEmbedRecord
    public let media: AppBskyEmbedRecordWithMediaMediaUnion

    public init(record: AppBskyEmbedRecord, media: AppBskyEmbedRecordWithMediaMediaUnion) {
        self.record = record
        self.media = media
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        record = try container.decode(AppBskyEmbedRecord.self, forKey: .record)

        media = try container.decode(AppBskyEmbedRecordWithMediaMediaUnion.self, forKey: .media)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(record, forKey: .record)

        try container.encode(media, forKey: .media)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(record)
        hasher.combine(media)
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? Self else { return false }
        if record != other.record {
            return false
        }
        if media != other.media {
            return false
        }
        return true
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.isEqual(to: rhs)
    }

    private enum CodingKeys: String, CodingKey {
        case record
        case media
    }

    public struct View: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.embed.recordWithMedia#view"
        public let record: AppBskyEmbedRecord.View
        public let media: ViewMediaUnion

        // Standard initializer
        public init(
            record: AppBskyEmbedRecord.View, media: ViewMediaUnion
        ) {
            self.record = record
            self.media = media
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                record = try container.decode(AppBskyEmbedRecord.View.self, forKey: .record)

            } catch {
                LogManager.logError("Decoding error for property 'record': \(error)")
                throw error
            }
            do {
                media = try container.decode(ViewMediaUnion.self, forKey: .media)

            } catch {
                LogManager.logError("Decoding error for property 'media': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(record, forKey: .record)

            try container.encode(media, forKey: .media)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(record)
            hasher.combine(media)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if record != other.record {
                return false
            }

            if media != other.media {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case record
            case media
        }
    }

    public enum ViewMediaUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, PendingDataLoadable, Equatable {
        case appBskyEmbedImagesView(AppBskyEmbedImages.View)
        case appBskyEmbedVideoView(AppBskyEmbedVideo.View)
        case appBskyEmbedExternalView(AppBskyEmbedExternal.View)
        case unexpected(ATProtocolValueContainer)

        public init(_ value: AppBskyEmbedImages.View) {
            self = .appBskyEmbedImagesView(value)
        }

        public init(_ value: AppBskyEmbedVideo.View) {
            self = .appBskyEmbedVideoView(value)
        }

        public init(_ value: AppBskyEmbedExternal.View) {
            self = .appBskyEmbedExternalView(value)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            switch typeValue {
            case "app.bsky.embed.images#view":
                let value = try AppBskyEmbedImages.View(from: decoder)
                self = .appBskyEmbedImagesView(value)
            case "app.bsky.embed.video#view":
                let value = try AppBskyEmbedVideo.View(from: decoder)
                self = .appBskyEmbedVideoView(value)
            case "app.bsky.embed.external#view":
                let value = try AppBskyEmbedExternal.View(from: decoder)
                self = .appBskyEmbedExternalView(value)
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .appBskyEmbedImagesView(value):
                try container.encode("app.bsky.embed.images#view", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyEmbedVideoView(value):
                try container.encode("app.bsky.embed.video#view", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyEmbedExternalView(value):
                try container.encode("app.bsky.embed.external#view", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .appBskyEmbedImagesView(value):
                hasher.combine("app.bsky.embed.images#view")
                hasher.combine(value)
            case let .appBskyEmbedVideoView(value):
                hasher.combine("app.bsky.embed.video#view")
                hasher.combine(value)
            case let .appBskyEmbedExternalView(value):
                hasher.combine("app.bsky.embed.external#view")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: ViewMediaUnion, rhs: ViewMediaUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .appBskyEmbedImagesView(lhsValue),
                .appBskyEmbedImagesView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyEmbedVideoView(lhsValue),
                .appBskyEmbedVideoView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyEmbedExternalView(lhsValue),
                .appBskyEmbedExternalView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? ViewMediaUnion else { return false }
            return self == other
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .appBskyEmbedImagesView(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .appBskyEmbedVideoView(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .appBskyEmbedExternalView(value):
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
            case var .appBskyEmbedImagesView(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? AppBskyEmbedImages.View {
                            self = .appBskyEmbedImagesView(updatedValue)
                        }
                    }
                }
            case var .appBskyEmbedVideoView(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? AppBskyEmbedVideo.View {
                            self = .appBskyEmbedVideoView(updatedValue)
                        }
                    }
                }
            case var .appBskyEmbedExternalView(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? (any PendingDataLoadable) {
                    if loadable.hasPendingData {
                        await loadable.loadPendingData()
                        // Update the value if it was mutated
                        if let updatedValue = loadable as? AppBskyEmbedExternal.View {
                            self = .appBskyEmbedExternalView(updatedValue)
                        }
                    }
                }
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }

    public enum AppBskyEmbedRecordWithMediaMediaUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, PendingDataLoadable, Equatable {
        case appBskyEmbedImages(AppBskyEmbedImages)
        case appBskyEmbedVideo(AppBskyEmbedVideo)
        case appBskyEmbedExternal(AppBskyEmbedExternal)
        case unexpected(ATProtocolValueContainer)

        public init(_ value: AppBskyEmbedImages) {
            self = .appBskyEmbedImages(value)
        }

        public init(_ value: AppBskyEmbedVideo) {
            self = .appBskyEmbedVideo(value)
        }

        public init(_ value: AppBskyEmbedExternal) {
            self = .appBskyEmbedExternal(value)
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
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: AppBskyEmbedRecordWithMediaMediaUnion, rhs: AppBskyEmbedRecordWithMediaMediaUnion) -> Bool {
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
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? AppBskyEmbedRecordWithMediaMediaUnion else { return false }
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
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }
}
