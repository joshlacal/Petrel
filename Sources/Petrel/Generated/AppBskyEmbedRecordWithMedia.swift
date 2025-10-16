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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            
            
            let recordValue = try record.toCBORValue()
            map = map.adding(key: "record", value: recordValue)
            
            
            
            let mediaValue = try media.toCBORValue()
            map = map.adding(key: "media", value: mediaValue)
            
            

            return map
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
                
                LogManager.logError("Decoding error for required property 'record': \(error)")
                
                throw error
            }
            do {
                
                
                self.media = try container.decode(ViewMediaUnion.self, forKey: .media)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'media': \(error)")
                
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let recordValue = try record.toCBORValue()
            map = map.adding(key: "record", value: recordValue)
            
            
            
            
            
            
            let mediaValue = try media.toCBORValue()
            map = map.adding(key: "media", value: mediaValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case record
            case media
        }
    }





public enum ViewMediaUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
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
        case .appBskyEmbedImagesView(let value):
            try container.encode("app.bsky.embed.images#view", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyEmbedVideoView(let value):
            try container.encode("app.bsky.embed.video#view", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyEmbedExternalView(let value):
            try container.encode("app.bsky.embed.external#view", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let container):
            try container.encode(to: encoder)
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
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: ViewMediaUnion, rhs: ViewMediaUnion) -> Bool {
        switch (lhs, rhs) {
        case (.appBskyEmbedImagesView(let lhsValue),
              .appBskyEmbedImagesView(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyEmbedVideoView(let lhsValue),
              .appBskyEmbedVideoView(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyEmbedExternalView(let lhsValue),
              .appBskyEmbedExternalView(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? ViewMediaUnion else { return false }
        return self == other
    }
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        // Create an ordered map to maintain field order
        var map = OrderedCBORMap()
        
        switch self {
        case .appBskyEmbedImagesView(let value):
            map = map.adding(key: "$type", value: "app.bsky.embed.images#view")
            
            let valueDict = try value.toCBORValue()

            // If the value is already an OrderedCBORMap, merge its entries
            if let orderedMap = valueDict as? OrderedCBORMap {
                for (key, value) in orderedMap.entries where key != "$type" {
                    map = map.adding(key: key, value: value)
                }
            } else if let dict = valueDict as? [String: Any] {
                // Otherwise add each key-value pair from the dictionary
                for (key, value) in dict where key != "$type" {
                    map = map.adding(key: key, value: value)
                }
            }
            return map
        case .appBskyEmbedVideoView(let value):
            map = map.adding(key: "$type", value: "app.bsky.embed.video#view")
            
            let valueDict = try value.toCBORValue()

            // If the value is already an OrderedCBORMap, merge its entries
            if let orderedMap = valueDict as? OrderedCBORMap {
                for (key, value) in orderedMap.entries where key != "$type" {
                    map = map.adding(key: key, value: value)
                }
            } else if let dict = valueDict as? [String: Any] {
                // Otherwise add each key-value pair from the dictionary
                for (key, value) in dict where key != "$type" {
                    map = map.adding(key: key, value: value)
                }
            }
            return map
        case .appBskyEmbedExternalView(let value):
            map = map.adding(key: "$type", value: "app.bsky.embed.external#view")
            
            let valueDict = try value.toCBORValue()

            // If the value is already an OrderedCBORMap, merge its entries
            if let orderedMap = valueDict as? OrderedCBORMap {
                for (key, value) in orderedMap.entries where key != "$type" {
                    map = map.adding(key: key, value: value)
                }
            } else if let dict = valueDict as? [String: Any] {
                // Otherwise add each key-value pair from the dictionary
                for (key, value) in dict where key != "$type" {
                    map = map.adding(key: key, value: value)
                }
            }
            return map
        case .unexpected(let container):
            return try container.toCBORValue()
        }
    }
}




public enum AppBskyEmbedRecordWithMediaMediaUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
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
        case .appBskyEmbedImages(let value):
            try container.encode("app.bsky.embed.images", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyEmbedVideo(let value):
            try container.encode("app.bsky.embed.video", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyEmbedExternal(let value):
            try container.encode("app.bsky.embed.external", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let container):
            try container.encode(to: encoder)
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
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: AppBskyEmbedRecordWithMediaMediaUnion, rhs: AppBskyEmbedRecordWithMediaMediaUnion) -> Bool {
        switch (lhs, rhs) {
        case (.appBskyEmbedImages(let lhsValue),
              .appBskyEmbedImages(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyEmbedVideo(let lhsValue),
              .appBskyEmbedVideo(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyEmbedExternal(let lhsValue),
              .appBskyEmbedExternal(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? AppBskyEmbedRecordWithMediaMediaUnion else { return false }
        return self == other
    }
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        // Create an ordered map to maintain field order
        var map = OrderedCBORMap()
        
        switch self {
        case .appBskyEmbedImages(let value):
            map = map.adding(key: "$type", value: "app.bsky.embed.images")
            
            let valueDict = try value.toCBORValue()

            // If the value is already an OrderedCBORMap, merge its entries
            if let orderedMap = valueDict as? OrderedCBORMap {
                for (key, value) in orderedMap.entries where key != "$type" {
                    map = map.adding(key: key, value: value)
                }
            } else if let dict = valueDict as? [String: Any] {
                // Otherwise add each key-value pair from the dictionary
                for (key, value) in dict where key != "$type" {
                    map = map.adding(key: key, value: value)
                }
            }
            return map
        case .appBskyEmbedVideo(let value):
            map = map.adding(key: "$type", value: "app.bsky.embed.video")
            
            let valueDict = try value.toCBORValue()

            // If the value is already an OrderedCBORMap, merge its entries
            if let orderedMap = valueDict as? OrderedCBORMap {
                for (key, value) in orderedMap.entries where key != "$type" {
                    map = map.adding(key: key, value: value)
                }
            } else if let dict = valueDict as? [String: Any] {
                // Otherwise add each key-value pair from the dictionary
                for (key, value) in dict where key != "$type" {
                    map = map.adding(key: key, value: value)
                }
            }
            return map
        case .appBskyEmbedExternal(let value):
            map = map.adding(key: "$type", value: "app.bsky.embed.external")
            
            let valueDict = try value.toCBORValue()

            // If the value is already an OrderedCBORMap, merge its entries
            if let orderedMap = valueDict as? OrderedCBORMap {
                for (key, value) in orderedMap.entries where key != "$type" {
                    map = map.adding(key: key, value: value)
                }
            } else if let dict = valueDict as? [String: Any] {
                // Otherwise add each key-value pair from the dictionary
                for (key, value) in dict where key != "$type" {
                    map = map.adding(key: key, value: value)
                }
            }
            return map
        case .unexpected(let container):
            return try container.toCBORValue()
        }
    }
}


}


                           
