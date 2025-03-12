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

    public enum ViewMediaUnion: Codable, ATProtocolCodable, ATProtocolValue {
        case appBskyEmbedImagesView(AppBskyEmbedImages.View)
        case appBskyEmbedVideoView(AppBskyEmbedVideo.View)
        case appBskyEmbedExternalView(AppBskyEmbedExternal.View)
        case unexpected(ATProtocolValueContainer)

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
            case let .unexpected(ATProtocolValueContainer):
                try ATProtocolValueContainer.encode(to: encoder)
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
            case let .unexpected(ATProtocolValueContainer):
                hasher.combine("unexpected")
                hasher.combine(ATProtocolValueContainer)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let otherValue = other as? ViewMediaUnion else { return false }

            switch (self, otherValue) {
            case let (
                .appBskyEmbedImagesView(selfValue),
                .appBskyEmbedImagesView(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .appBskyEmbedVideoView(selfValue),
                .appBskyEmbedVideoView(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .appBskyEmbedExternalView(selfValue),
                .appBskyEmbedExternalView(otherValue)
            ):
                return selfValue == otherValue
            case let (.unexpected(selfValue), .unexpected(otherValue)):
                return selfValue.isEqual(to: otherValue)
            default:
                return false
            }
        }
    }

    public enum AppBskyEmbedRecordWithMediaMediaUnion: Codable, ATProtocolCodable, ATProtocolValue {
        case appBskyEmbedImages(AppBskyEmbedImages)
        case appBskyEmbedVideo(AppBskyEmbedVideo)
        case appBskyEmbedExternal(AppBskyEmbedExternal)
        case unexpected(ATProtocolValueContainer)

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
            case let .unexpected(ATProtocolValueContainer):
                try ATProtocolValueContainer.encode(to: encoder)
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
            case let .unexpected(ATProtocolValueContainer):
                hasher.combine("unexpected")
                hasher.combine(ATProtocolValueContainer)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let otherValue = other as? AppBskyEmbedRecordWithMediaMediaUnion else { return false }

            switch (self, otherValue) {
            case let (
                .appBskyEmbedImages(selfValue),
                .appBskyEmbedImages(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .appBskyEmbedVideo(selfValue),
                .appBskyEmbedVideo(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .appBskyEmbedExternal(selfValue),
                .appBskyEmbedExternal(otherValue)
            ):
                return selfValue == otherValue
            case let (.unexpected(selfValue), .unexpected(otherValue)):
                return selfValue.isEqual(to: otherValue)
            default:
                return false
            }
        }
    }
}
