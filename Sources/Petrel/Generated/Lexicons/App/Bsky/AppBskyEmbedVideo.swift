import Foundation

// lexicon: 1, id: app.bsky.embed.video

public struct AppBskyEmbedVideo: ATProtocolCodable, ATProtocolValue {
    public static let typeIdentifier = "app.bsky.embed.video"
    public let video: Blob
    public let captions: [Caption]?
    public let alt: String?
    public let aspectRatio: AppBskyEmbedDefs.AspectRatio?
    public let presentation: String?

    public init(video: Blob, captions: [Caption]?, alt: String?, aspectRatio: AppBskyEmbedDefs.AspectRatio?, presentation: String?) {
        self.video = video
        self.captions = captions
        self.alt = alt
        self.aspectRatio = aspectRatio
        self.presentation = presentation
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        video = try container.decode(Blob.self, forKey: .video)
        captions = try container.decodeIfPresent([Caption].self, forKey: .captions)
        alt = try container.decodeIfPresent(String.self, forKey: .alt)
        aspectRatio = try container.decodeIfPresent(AppBskyEmbedDefs.AspectRatio.self, forKey: .aspectRatio)
        presentation = try container.decodeIfPresent(String.self, forKey: .presentation)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(video, forKey: .video)
        try container.encodeIfPresent(captions, forKey: .captions)
        try container.encodeIfPresent(alt, forKey: .alt)
        try container.encodeIfPresent(aspectRatio, forKey: .aspectRatio)
        try container.encodeIfPresent(presentation, forKey: .presentation)
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
        if let value = presentation {
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
        if presentation != other.presentation {
            return false
        }
        return true
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.isEqual(to: rhs)
    }

    public func toCBORValue() throws -> Any {
        var map = OrderedCBORMap()
        let videoValue = try video.toCBORValue()
        map = map.adding(key: "video", value: videoValue)
        if let value = captions {
            let captionsValue = try value.toCBORValue()
            map = map.adding(key: "captions", value: captionsValue)
        }
        if let value = alt {
            let altValue = try value.toCBORValue()
            map = map.adding(key: "alt", value: altValue)
        }
        if let value = aspectRatio {
            let aspectRatioValue = try value.toCBORValue()
            map = map.adding(key: "aspectRatio", value: aspectRatioValue)
        }
        if let value = presentation {
            let presentationValue = try value.toCBORValue()
            map = map.adding(key: "presentation", value: presentationValue)
        }
        return map
    }

    private enum CodingKeys: String, CodingKey {
        case video
        case captions
        case alt
        case aspectRatio
        case presentation
    }

    public struct Caption: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.embed.video#caption"
        public let lang: LanguageCodeContainer
        public let file: Blob

        public init(
            lang: LanguageCodeContainer, file: Blob
        ) {
            self.lang = lang
            self.file = file
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                lang = try container.decode(LanguageCodeContainer.self, forKey: .lang)
            } catch {
                LogManager.logError("Decoding error for required property 'lang': \(error)")
                throw error
            }
            do {
                file = try container.decode(Blob.self, forKey: .file)
            } catch {
                LogManager.logError("Decoding error for required property 'file': \(error)")
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

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let langValue = try lang.toCBORValue()
            map = map.adding(key: "lang", value: langValue)
            let fileValue = try file.toCBORValue()
            map = map.adding(key: "file", value: fileValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case lang
            case file
        }
    }

    public struct View: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.embed.video#view"
        public let cid: CID
        public let playlist: URI
        public let thumbnail: URI?
        public let alt: String?
        public let aspectRatio: AppBskyEmbedDefs.AspectRatio?
        public let presentation: String?

        public init(
            cid: CID, playlist: URI, thumbnail: URI?, alt: String?, aspectRatio: AppBskyEmbedDefs.AspectRatio?, presentation: String?
        ) {
            self.cid = cid
            self.playlist = playlist
            self.thumbnail = thumbnail
            self.alt = alt
            self.aspectRatio = aspectRatio
            self.presentation = presentation
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                cid = try container.decode(CID.self, forKey: .cid)
            } catch {
                LogManager.logError("Decoding error for required property 'cid': \(error)")
                throw error
            }
            do {
                playlist = try container.decode(URI.self, forKey: .playlist)
            } catch {
                LogManager.logError("Decoding error for required property 'playlist': \(error)")
                throw error
            }
            do {
                thumbnail = try container.decodeIfPresent(URI.self, forKey: .thumbnail)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'thumbnail': \(error)")
                throw error
            }
            do {
                alt = try container.decodeIfPresent(String.self, forKey: .alt)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'alt': \(error)")
                throw error
            }
            do {
                aspectRatio = try container.decodeIfPresent(AppBskyEmbedDefs.AspectRatio.self, forKey: .aspectRatio)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'aspectRatio': \(error)")
                throw error
            }
            do {
                presentation = try container.decodeIfPresent(String.self, forKey: .presentation)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'presentation': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(cid, forKey: .cid)
            try container.encode(playlist, forKey: .playlist)
            try container.encodeIfPresent(thumbnail, forKey: .thumbnail)
            try container.encodeIfPresent(alt, forKey: .alt)
            try container.encodeIfPresent(aspectRatio, forKey: .aspectRatio)
            try container.encodeIfPresent(presentation, forKey: .presentation)
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
            if let value = presentation {
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
            if presentation != other.presentation {
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
            let cidValue = try cid.toCBORValue()
            map = map.adding(key: "cid", value: cidValue)
            let playlistValue = try playlist.toCBORValue()
            map = map.adding(key: "playlist", value: playlistValue)
            if let value = thumbnail {
                let thumbnailValue = try value.toCBORValue()
                map = map.adding(key: "thumbnail", value: thumbnailValue)
            }
            if let value = alt {
                let altValue = try value.toCBORValue()
                map = map.adding(key: "alt", value: altValue)
            }
            if let value = aspectRatio {
                let aspectRatioValue = try value.toCBORValue()
                map = map.adding(key: "aspectRatio", value: aspectRatioValue)
            }
            if let value = presentation {
                let presentationValue = try value.toCBORValue()
                map = map.adding(key: "presentation", value: presentationValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case cid
            case playlist
            case thumbnail
            case alt
            case aspectRatio
            case presentation
        }
    }
}
