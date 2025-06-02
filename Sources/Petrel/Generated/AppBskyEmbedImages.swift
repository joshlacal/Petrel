import Foundation

// lexicon: 1, id: app.bsky.embed.images

public struct AppBskyEmbedImages: ATProtocolCodable, ATProtocolValue {
    public static let typeIdentifier = "app.bsky.embed.images"
    public let images: [Image]

    public init(images: [Image]) {
        self.images = images
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        images = try container.decode([Image].self, forKey: .images)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(images, forKey: .images)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(images)
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? Self else { return false }
        if images != other.images {
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

        let imagesValue = try images.toCBORValue()
        map = map.adding(key: "images", value: imagesValue)

        return map
    }

    private enum CodingKeys: String, CodingKey {
        case images
    }

    public struct Image: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.embed.images#image"
        public let image: Blob
        public let alt: String
        public let aspectRatio: AppBskyEmbedDefs.AspectRatio?

        // Standard initializer
        public init(
            image: Blob, alt: String, aspectRatio: AppBskyEmbedDefs.AspectRatio?
        ) {
            self.image = image
            self.alt = alt
            self.aspectRatio = aspectRatio
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                image = try container.decode(Blob.self, forKey: .image)

            } catch {
                LogManager.logError("Decoding error for property 'image': \(error)")
                throw error
            }
            do {
                alt = try container.decode(String.self, forKey: .alt)

            } catch {
                LogManager.logError("Decoding error for property 'alt': \(error)")
                throw error
            }
            do {
                aspectRatio = try container.decodeIfPresent(AppBskyEmbedDefs.AspectRatio.self, forKey: .aspectRatio)

            } catch {
                LogManager.logError("Decoding error for property 'aspectRatio': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(image, forKey: .image)

            try container.encode(alt, forKey: .alt)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(aspectRatio, forKey: .aspectRatio)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(image)
            hasher.combine(alt)
            if let value = aspectRatio {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let imageValue = try image.toCBORValue()
            map = map.adding(key: "image", value: imageValue)

            let altValue = try alt.toCBORValue()
            map = map.adding(key: "alt", value: altValue)

            if let value = aspectRatio {
                // Encode optional property even if it's an empty array for CBOR

                let aspectRatioValue = try value.toCBORValue()
                map = map.adding(key: "aspectRatio", value: aspectRatioValue)
            }

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
        public static let typeIdentifier = "app.bsky.embed.images#view"
        public let images: [ViewImage]

        // Standard initializer
        public init(
            images: [ViewImage]
        ) {
            self.images = images
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                images = try container.decode([ViewImage].self, forKey: .images)

            } catch {
                LogManager.logError("Decoding error for property 'images': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(images, forKey: .images)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(images)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if images != other.images {
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

            let imagesValue = try images.toCBORValue()
            map = map.adding(key: "images", value: imagesValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case images
        }
    }

    public struct ViewImage: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.embed.images#viewImage"
        public let thumb: URI
        public let fullsize: URI
        public let alt: String
        public let aspectRatio: AppBskyEmbedDefs.AspectRatio?

        // Standard initializer
        public init(
            thumb: URI, fullsize: URI, alt: String, aspectRatio: AppBskyEmbedDefs.AspectRatio?
        ) {
            self.thumb = thumb
            self.fullsize = fullsize
            self.alt = alt
            self.aspectRatio = aspectRatio
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                thumb = try container.decode(URI.self, forKey: .thumb)

            } catch {
                LogManager.logError("Decoding error for property 'thumb': \(error)")
                throw error
            }
            do {
                fullsize = try container.decode(URI.self, forKey: .fullsize)

            } catch {
                LogManager.logError("Decoding error for property 'fullsize': \(error)")
                throw error
            }
            do {
                alt = try container.decode(String.self, forKey: .alt)

            } catch {
                LogManager.logError("Decoding error for property 'alt': \(error)")
                throw error
            }
            do {
                aspectRatio = try container.decodeIfPresent(AppBskyEmbedDefs.AspectRatio.self, forKey: .aspectRatio)

            } catch {
                LogManager.logError("Decoding error for property 'aspectRatio': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(thumb, forKey: .thumb)

            try container.encode(fullsize, forKey: .fullsize)

            try container.encode(alt, forKey: .alt)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(aspectRatio, forKey: .aspectRatio)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(thumb)
            hasher.combine(fullsize)
            hasher.combine(alt)
            if let value = aspectRatio {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if thumb != other.thumb {
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let thumbValue = try thumb.toCBORValue()
            map = map.adding(key: "thumb", value: thumbValue)

            let fullsizeValue = try fullsize.toCBORValue()
            map = map.adding(key: "fullsize", value: fullsizeValue)

            let altValue = try alt.toCBORValue()
            map = map.adding(key: "alt", value: altValue)

            if let value = aspectRatio {
                // Encode optional property even if it's an empty array for CBOR

                let aspectRatioValue = try value.toCBORValue()
                map = map.adding(key: "aspectRatio", value: aspectRatioValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case thumb
            case fullsize
            case alt
            case aspectRatio
        }
    }
}
