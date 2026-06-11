import Foundation

// lexicon: 1, id: app.bsky.embed.gallery

public struct AppBskyEmbedGallery: ATProtocolCodable, ATProtocolValue {
    public static let typeIdentifier = "app.bsky.embed.gallery"
    public let items: [AppBskyEmbedGalleryItemsUnion]

    public init(items: [AppBskyEmbedGalleryItemsUnion]) {
        self.items = items
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decode([AppBskyEmbedGalleryItemsUnion].self, forKey: .items)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(items, forKey: .items)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(items)
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? Self else { return false }
        if items != other.items {
            return false
        }
        return true
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.isEqual(to: rhs)
    }

    public func toCBORValue() throws -> Any {
        var map = OrderedCBORMap()
        let itemsValue = try items.toCBORValue()
        map = map.adding(key: "items", value: itemsValue)
        return map
    }

    private enum CodingKeys: String, CodingKey {
        case items
    }

    public struct Image: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.embed.gallery#image"
        public let image: Blob
        public let alt: String
        public let aspectRatio: AppBskyEmbedDefs.AspectRatio

        public init(
            image: Blob, alt: String, aspectRatio: AppBskyEmbedDefs.AspectRatio
        ) {
            self.image = image
            self.alt = alt
            self.aspectRatio = aspectRatio
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                image = try container.decode(Blob.self, forKey: .image)
            } catch {
                LogManager.logError("Decoding error for required property 'image': \(error)")
                throw error
            }
            do {
                alt = try container.decode(String.self, forKey: .alt)
            } catch {
                LogManager.logError("Decoding error for required property 'alt': \(error)")
                throw error
            }
            do {
                aspectRatio = try container.decode(AppBskyEmbedDefs.AspectRatio.self, forKey: .aspectRatio)
            } catch {
                LogManager.logError("Decoding error for required property 'aspectRatio': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(image, forKey: .image)
            try container.encode(alt, forKey: .alt)
            try container.encode(aspectRatio, forKey: .aspectRatio)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(image)
            hasher.combine(alt)
            hasher.combine(aspectRatio)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if image != other.image {
                return false
            }
            if alt != other.alt {
                return false
            }
            if aspectRatio != other.aspectRatio {
                return false
            }
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let imageValue = try image.toCBORValue()
            map = map.adding(key: "image", value: imageValue)
            let altValue = try alt.toCBORValue()
            map = map.adding(key: "alt", value: altValue)
            let aspectRatioValue = try aspectRatio.toCBORValue()
            map = map.adding(key: "aspectRatio", value: aspectRatioValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case image
            case alt
            case aspectRatio
        }
    }

    public struct View: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.embed.gallery#view"
        public let items: [ViewItemsUnion]

        public init(
            items: [ViewItemsUnion]
        ) {
            self.items = items
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                items = try container.decode([ViewItemsUnion].self, forKey: .items)
            } catch {
                LogManager.logError("Decoding error for required property 'items': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(items, forKey: .items)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(items)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if items != other.items {
                return false
            }
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let itemsValue = try items.toCBORValue()
            map = map.adding(key: "items", value: itemsValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case items
        }
    }

    public struct ViewImage: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.embed.gallery#viewImage"
        public let thumbnail: URI
        public let fullsize: URI
        public let alt: String
        public let aspectRatio: AppBskyEmbedDefs.AspectRatio

        public init(
            thumbnail: URI, fullsize: URI, alt: String, aspectRatio: AppBskyEmbedDefs.AspectRatio
        ) {
            self.thumbnail = thumbnail
            self.fullsize = fullsize
            self.alt = alt
            self.aspectRatio = aspectRatio
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                thumbnail = try container.decode(URI.self, forKey: .thumbnail)
            } catch {
                LogManager.logError("Decoding error for required property 'thumbnail': \(error)")
                throw error
            }
            do {
                fullsize = try container.decode(URI.self, forKey: .fullsize)
            } catch {
                LogManager.logError("Decoding error for required property 'fullsize': \(error)")
                throw error
            }
            do {
                alt = try container.decode(String.self, forKey: .alt)
            } catch {
                LogManager.logError("Decoding error for required property 'alt': \(error)")
                throw error
            }
            do {
                aspectRatio = try container.decode(AppBskyEmbedDefs.AspectRatio.self, forKey: .aspectRatio)
            } catch {
                LogManager.logError("Decoding error for required property 'aspectRatio': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(thumbnail, forKey: .thumbnail)
            try container.encode(fullsize, forKey: .fullsize)
            try container.encode(alt, forKey: .alt)
            try container.encode(aspectRatio, forKey: .aspectRatio)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(thumbnail)
            hasher.combine(fullsize)
            hasher.combine(alt)
            hasher.combine(aspectRatio)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if thumbnail != other.thumbnail {
                return false
            }
            if fullsize != other.fullsize {
                return false
            }
            if alt != other.alt {
                return false
            }
            if aspectRatio != other.aspectRatio {
                return false
            }
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let thumbnailValue = try thumbnail.toCBORValue()
            map = map.adding(key: "thumbnail", value: thumbnailValue)
            let fullsizeValue = try fullsize.toCBORValue()
            map = map.adding(key: "fullsize", value: fullsizeValue)
            let altValue = try alt.toCBORValue()
            map = map.adding(key: "alt", value: altValue)
            let aspectRatioValue = try aspectRatio.toCBORValue()
            map = map.adding(key: "aspectRatio", value: aspectRatioValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case thumbnail
            case fullsize
            case alt
            case aspectRatio
        }
    }

    public enum ViewItemsUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case appBskyEmbedGalleryViewImage(AppBskyEmbedGallery.ViewImage)
        case unexpected(ATProtocolValueContainer)
        public init(_ value: AppBskyEmbedGallery.ViewImage) {
            self = .appBskyEmbedGalleryViewImage(value)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            switch typeValue {
            case "app.bsky.embed.gallery#viewImage":
                let value = try AppBskyEmbedGallery.ViewImage(from: decoder)
                self = .appBskyEmbedGalleryViewImage(value)
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .appBskyEmbedGalleryViewImage(value):
                try container.encode("app.bsky.embed.gallery#viewImage", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .appBskyEmbedGalleryViewImage(value):
                hasher.combine("app.bsky.embed.gallery#viewImage")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: ViewItemsUnion, rhs: ViewItemsUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .appBskyEmbedGalleryViewImage(lhsValue),
                .appBskyEmbedGalleryViewImage(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? ViewItemsUnion else { return false }
            return self == other
        }

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .appBskyEmbedGalleryViewImage(value):
                map = map.adding(key: "$type", value: "app.bsky.embed.gallery#viewImage")

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
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }
    }

    public enum AppBskyEmbedGalleryItemsUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case appBskyEmbedGalleryImage(AppBskyEmbedGallery.Image)
        case unexpected(ATProtocolValueContainer)
        public init(_ value: AppBskyEmbedGallery.Image) {
            self = .appBskyEmbedGalleryImage(value)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            switch typeValue {
            case "app.bsky.embed.gallery#image":
                let value = try AppBskyEmbedGallery.Image(from: decoder)
                self = .appBskyEmbedGalleryImage(value)
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .appBskyEmbedGalleryImage(value):
                try container.encode("app.bsky.embed.gallery#image", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .appBskyEmbedGalleryImage(value):
                hasher.combine("app.bsky.embed.gallery#image")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: AppBskyEmbedGalleryItemsUnion, rhs: AppBskyEmbedGalleryItemsUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .appBskyEmbedGalleryImage(lhsValue),
                .appBskyEmbedGalleryImage(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? AppBskyEmbedGalleryItemsUnion else { return false }
            return self == other
        }

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .appBskyEmbedGalleryImage(value):
                map = map.adding(key: "$type", value: "app.bsky.embed.gallery#image")

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
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }
    }

    // Union Array Type

    public struct Items: Codable, ATProtocolCodable, ATProtocolValue {
        public let items: [ItemsForUnionArray]

        public init(items: [ItemsForUnionArray]) {
            self.items = items
        }

        public init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            var items = [ItemsForUnionArray]()
            while !container.isAtEnd {
                let item = try container.decode(ItemsForUnionArray.self)
                items.append(item)
            }
            self.items = items
        }

        public func encode(to encoder: Encoder) throws {
            // Encode the array regardless of whether it's empty
            var container = encoder.unkeyedContainer()
            for item in items {
                try container.encode(item)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Items else { return false }

            if items != other.items {
                return false
            }

            return true
        }

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // For union arrays, we need to encode each item while preserving its order
            var itemsArray = [Any]()

            for item in items {
                let itemValue = try item.toCBORValue()
                itemsArray.append(itemValue)
            }

            return itemsArray
        }
    }

    public enum ItemsForUnionArray: Codable, ATProtocolCodable, ATProtocolValue {
        case image(Image)
        case unexpected(ATProtocolValueContainer)
        public init(_ value: Image) {
            self = .image(value)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            switch typeValue {
            case "Image":
                let value = try Image(from: decoder)
                self = .image(value)
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .image(value):
                try container.encode("Image", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(ATProtocolValueContainer):
                try ATProtocolValueContainer.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .image(value):
                hasher.combine("Image")
                hasher.combine(value)
            case let .unexpected(ATProtocolValueContainer):
                hasher.combine("unexpected")
                hasher.combine(ATProtocolValueContainer)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let otherValue = other as? ItemsForUnionArray else { return false }

            switch (self, otherValue) {
            case let (
                .image(selfValue),
                .image(otherValue)
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

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            switch self {
            case let .image(value):
                map = map.adding(key: "$type", value: "Image")

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
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }
    }
}
