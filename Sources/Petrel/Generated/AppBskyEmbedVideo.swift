import Foundation
import ZippyJSON

// lexicon: 1, id: app.bsky.embed.video

public struct AppBskyEmbedVideo: ATProtocolCodable, ATProtocolValue {
    public static let typeIdentifier = "app.bsky.embed.video"
    public let video: Blob
    public let captions: [Caption]?
    public let alt: String?
    public let aspectRatio: AppBskyEmbedDefs.AspectRatio?

    public init(video: Blob, captions: [Caption]?, alt: String?, aspectRatio: AppBskyEmbedDefs.AspectRatio?) {
        self.video = video
        self.captions = captions
        self.alt = alt
        self.aspectRatio = aspectRatio
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        video = try container.decode(Blob.self, forKey: .video)

        captions = try container.decodeIfPresent([Caption].self, forKey: .captions)

        alt = try container.decodeIfPresent(String.self, forKey: .alt)

        aspectRatio = try container.decodeIfPresent(AppBskyEmbedDefs.AspectRatio.self, forKey: .aspectRatio)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(video, forKey: .video)

        if let value = captions {
            try container.encode(value, forKey: .captions)
        }

        if let value = alt {
            try container.encode(value, forKey: .alt)
        }

        if let value = aspectRatio {
            try container.encode(value, forKey: .aspectRatio)
        }
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(video)
        if let value = captions {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?)
        }
        if let value = alt {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?)
        }
        if let value = aspectRatio {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?)
        }
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? Self else { return false }
        if video != other.video {
            return false
        }
        if captions != other.captions {
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

    private enum CodingKeys: String, CodingKey {
        case video
        case captions
        case alt
        case aspectRatio
    }

    public struct Caption: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.embed.video#caption"
        public let lang: LanguageCodeContainer
        public let file: Blob

        // Standard initializer
        public init(
            lang: LanguageCodeContainer, file: Blob
        ) {
            self.lang = lang
            self.file = file
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                lang = try container.decode(LanguageCodeContainer.self, forKey: .lang)

            } catch {
                LogManager.logError("Decoding error for property 'lang': \(error)")
                throw error
            }
            do {
                file = try container.decode(Blob.self, forKey: .file)

            } catch {
                LogManager.logError("Decoding error for property 'file': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(lang, forKey: .lang)

            try container.encode(file, forKey: .file)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(lang)
            hasher.combine(file)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if lang != other.lang {
                return false
            }

            if file != other.file {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case lang
            case file
        }
    }

    public struct View: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.embed.video#view"
        public let cid: String
        public let playlist: URI
        public let thumbnail: URI?
        public let alt: String?
        public let aspectRatio: AppBskyEmbedDefs.AspectRatio?

        // Standard initializer
        public init(
            cid: String, playlist: URI, thumbnail: URI?, alt: String?, aspectRatio: AppBskyEmbedDefs.AspectRatio?
        ) {
            self.cid = cid
            self.playlist = playlist
            self.thumbnail = thumbnail
            self.alt = alt
            self.aspectRatio = aspectRatio
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                cid = try container.decode(String.self, forKey: .cid)

            } catch {
                LogManager.logError("Decoding error for property 'cid': \(error)")
                throw error
            }
            do {
                playlist = try container.decode(URI.self, forKey: .playlist)

            } catch {
                LogManager.logError("Decoding error for property 'playlist': \(error)")
                throw error
            }
            do {
                thumbnail = try container.decodeIfPresent(URI.self, forKey: .thumbnail)

            } catch {
                LogManager.logError("Decoding error for property 'thumbnail': \(error)")
                throw error
            }
            do {
                alt = try container.decodeIfPresent(String.self, forKey: .alt)

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

            try container.encode(cid, forKey: .cid)

            try container.encode(playlist, forKey: .playlist)

            if let value = thumbnail {
                try container.encode(value, forKey: .thumbnail)
            }

            if let value = alt {
                try container.encode(value, forKey: .alt)
            }

            if let value = aspectRatio {
                try container.encode(value, forKey: .aspectRatio)
            }
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(cid)
            hasher.combine(playlist)
            if let value = thumbnail {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = alt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = aspectRatio {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if cid != other.cid {
                return false
            }

            if playlist != other.playlist {
                return false
            }

            if thumbnail != other.thumbnail {
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

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case cid
            case playlist
            case thumbnail
            case alt
            case aspectRatio
        }
    }
}
