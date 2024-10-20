import Foundation
import ZippyJSON


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
            
            self.record = try container.decode(AppBskyEmbedRecord.self, forKey: .record)
            
            
            self.media = try container.decode(AppBskyEmbedRecordWithMediaMediaUnion.self, forKey: .media)
            
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
            if self.record != other.record {
                return false
            }
            if self.media != other.media {
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
                
                self.record = try container.decode(AppBskyEmbedRecord.View.self, forKey: .record)
                
            } catch {
                LogManager.logError("Decoding error for property 'record': \(error)")
                throw error
            }
            do {
                
                self.media = try container.decode(ViewMediaUnion.self, forKey: .media)
                
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
            
            if self.record != other.record {
                return false
            }
            
            
            if self.media != other.media {
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
        case .appBskyEmbedImagesView(let value):
            try container.encode("app.bsky.embed.images#view", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyEmbedVideoView(let value):
            try container.encode("app.bsky.embed.video#view", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyEmbedExternalView(let value):
            try container.encode("app.bsky.embed.external#view", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let ATProtocolValueContainer):
            try ATProtocolValueContainer.encode(to: encoder)
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .appBskyEmbedImagesView(let value):
            hasher.combine("app.bsky.embed.images#view")
            hasher.combine(value)
        case .appBskyEmbedVideoView(let value):
            hasher.combine("app.bsky.embed.video#view")
            hasher.combine(value)
        case .appBskyEmbedExternalView(let value):
            hasher.combine("app.bsky.embed.external#view")
            hasher.combine(value)
        case .unexpected(let ATProtocolValueContainer):
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
            case (.appBskyEmbedImagesView(let selfValue), 
                .appBskyEmbedImagesView(let otherValue)):
                return selfValue == otherValue
            case (.appBskyEmbedVideoView(let selfValue), 
                .appBskyEmbedVideoView(let otherValue)):
                return selfValue == otherValue
            case (.appBskyEmbedExternalView(let selfValue), 
                .appBskyEmbedExternalView(let otherValue)):
                return selfValue == otherValue
            case (.unexpected(let selfValue), .unexpected(let otherValue)):
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
        case .appBskyEmbedImages(let value):
            try container.encode("app.bsky.embed.images", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyEmbedVideo(let value):
            try container.encode("app.bsky.embed.video", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyEmbedExternal(let value):
            try container.encode("app.bsky.embed.external", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let ATProtocolValueContainer):
            try ATProtocolValueContainer.encode(to: encoder)
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .appBskyEmbedImages(let value):
            hasher.combine("app.bsky.embed.images")
            hasher.combine(value)
        case .appBskyEmbedVideo(let value):
            hasher.combine("app.bsky.embed.video")
            hasher.combine(value)
        case .appBskyEmbedExternal(let value):
            hasher.combine("app.bsky.embed.external")
            hasher.combine(value)
        case .unexpected(let ATProtocolValueContainer):
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
            case (.appBskyEmbedImages(let selfValue), 
                .appBskyEmbedImages(let otherValue)):
                return selfValue == otherValue
            case (.appBskyEmbedVideo(let selfValue), 
                .appBskyEmbedVideo(let otherValue)):
                return selfValue == otherValue
            case (.appBskyEmbedExternal(let selfValue), 
                .appBskyEmbedExternal(let otherValue)):
                return selfValue == otherValue
            case (.unexpected(let selfValue), .unexpected(let otherValue)):
                return selfValue.isEqual(to: otherValue)
            default:
                return false
        }
    }
}


}


                           
