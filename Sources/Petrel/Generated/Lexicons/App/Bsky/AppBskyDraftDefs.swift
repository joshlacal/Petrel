import Foundation

// lexicon: 1, id: app.bsky.draft.defs

public enum AppBskyDraftDefs {
    public static let typeIdentifier = "app.bsky.draft.defs"

    public struct DraftWithId: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.draft.defs#draftWithId"
        public let id: TID
        public let draft: Draft

        public init(
            id: TID, draft: Draft
        ) {
            self.id = id
            self.draft = draft
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                id = try container.decode(TID.self, forKey: .id)
            } catch {
                LogManager.logError("Decoding error for required property 'id': \(error)")
                throw error
            }
            do {
                draft = try container.decode(Draft.self, forKey: .draft)
            } catch {
                LogManager.logError("Decoding error for required property 'draft': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(id, forKey: .id)
            try container.encode(draft, forKey: .draft)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(draft)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if id != other.id {
                return false
            }
            if draft != other.draft {
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
            let idValue = try id.toCBORValue()
            map = map.adding(key: "id", value: idValue)
            let draftValue = try draft.toCBORValue()
            map = map.adding(key: "draft", value: draftValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case id
            case draft
        }
    }

    public struct Draft: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.draft.defs#draft"
        public let deviceId: String?
        public let deviceName: String?
        public let posts: [DraftPost]
        public let langs: [LanguageCodeContainer]?
        public let postgateEmbeddingRules: [DraftPostgateEmbeddingRulesUnion]?
        public let threadgateAllow: [DraftThreadgateAllowUnion]?

        public init(
            deviceId: String?, deviceName: String?, posts: [DraftPost], langs: [LanguageCodeContainer]?, postgateEmbeddingRules: [DraftPostgateEmbeddingRulesUnion]?, threadgateAllow: [DraftThreadgateAllowUnion]?
        ) {
            self.deviceId = deviceId
            self.deviceName = deviceName
            self.posts = posts
            self.langs = langs
            self.postgateEmbeddingRules = postgateEmbeddingRules
            self.threadgateAllow = threadgateAllow
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                deviceId = try container.decodeIfPresent(String.self, forKey: .deviceId)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'deviceId': \(error)")
                throw error
            }
            do {
                deviceName = try container.decodeIfPresent(String.self, forKey: .deviceName)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'deviceName': \(error)")
                throw error
            }
            do {
                posts = try container.decode([DraftPost].self, forKey: .posts)
            } catch {
                LogManager.logError("Decoding error for required property 'posts': \(error)")
                throw error
            }
            do {
                langs = try container.decodeIfPresent([LanguageCodeContainer].self, forKey: .langs)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'langs': \(error)")
                throw error
            }
            do {
                postgateEmbeddingRules = try container.decodeIfPresent([DraftPostgateEmbeddingRulesUnion].self, forKey: .postgateEmbeddingRules)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'postgateEmbeddingRules': \(error)")
                throw error
            }
            do {
                threadgateAllow = try container.decodeIfPresent([DraftThreadgateAllowUnion].self, forKey: .threadgateAllow)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'threadgateAllow': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encodeIfPresent(deviceId, forKey: .deviceId)
            try container.encodeIfPresent(deviceName, forKey: .deviceName)
            try container.encode(posts, forKey: .posts)
            try container.encodeIfPresent(langs, forKey: .langs)
            try container.encodeIfPresent(postgateEmbeddingRules, forKey: .postgateEmbeddingRules)
            try container.encodeIfPresent(threadgateAllow, forKey: .threadgateAllow)
        }

        public func hash(into hasher: inout Hasher) {
            if let value = deviceId {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = deviceName {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(posts)
            if let value = langs {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = postgateEmbeddingRules {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = threadgateAllow {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if deviceId != other.deviceId {
                return false
            }
            if deviceName != other.deviceName {
                return false
            }
            if posts != other.posts {
                return false
            }
            if langs != other.langs {
                return false
            }
            if postgateEmbeddingRules != other.postgateEmbeddingRules {
                return false
            }
            if threadgateAllow != other.threadgateAllow {
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
            if let value = deviceId {
                let deviceIdValue = try value.toCBORValue()
                map = map.adding(key: "deviceId", value: deviceIdValue)
            }
            if let value = deviceName {
                let deviceNameValue = try value.toCBORValue()
                map = map.adding(key: "deviceName", value: deviceNameValue)
            }
            let postsValue = try posts.toCBORValue()
            map = map.adding(key: "posts", value: postsValue)
            if let value = langs {
                let langsValue = try value.toCBORValue()
                map = map.adding(key: "langs", value: langsValue)
            }
            if let value = postgateEmbeddingRules {
                let postgateEmbeddingRulesValue = try value.toCBORValue()
                map = map.adding(key: "postgateEmbeddingRules", value: postgateEmbeddingRulesValue)
            }
            if let value = threadgateAllow {
                let threadgateAllowValue = try value.toCBORValue()
                map = map.adding(key: "threadgateAllow", value: threadgateAllowValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case deviceId
            case deviceName
            case posts
            case langs
            case postgateEmbeddingRules
            case threadgateAllow
        }
    }

    public struct DraftPost: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.draft.defs#draftPost"
        public let text: String
        public let labels: DraftPostLabelsUnion?
        public let embedImages: [DraftEmbedImage]?
        public let embedVideos: [DraftEmbedVideo]?
        public let embedExternals: [DraftEmbedExternal]?
        public let embedRecords: [DraftEmbedRecord]?

        public init(
            text: String, labels: DraftPostLabelsUnion?, embedImages: [DraftEmbedImage]?, embedVideos: [DraftEmbedVideo]?, embedExternals: [DraftEmbedExternal]?, embedRecords: [DraftEmbedRecord]?
        ) {
            self.text = text
            self.labels = labels
            self.embedImages = embedImages
            self.embedVideos = embedVideos
            self.embedExternals = embedExternals
            self.embedRecords = embedRecords
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                text = try container.decode(String.self, forKey: .text)
            } catch {
                LogManager.logError("Decoding error for required property 'text': \(error)")
                throw error
            }
            do {
                labels = try container.decodeIfPresent(DraftPostLabelsUnion.self, forKey: .labels)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'labels': \(error)")
                throw error
            }
            do {
                embedImages = try container.decodeIfPresent([DraftEmbedImage].self, forKey: .embedImages)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'embedImages': \(error)")
                throw error
            }
            do {
                embedVideos = try container.decodeIfPresent([DraftEmbedVideo].self, forKey: .embedVideos)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'embedVideos': \(error)")
                throw error
            }
            do {
                embedExternals = try container.decodeIfPresent([DraftEmbedExternal].self, forKey: .embedExternals)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'embedExternals': \(error)")
                throw error
            }
            do {
                embedRecords = try container.decodeIfPresent([DraftEmbedRecord].self, forKey: .embedRecords)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'embedRecords': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(text, forKey: .text)
            try container.encodeIfPresent(labels, forKey: .labels)
            try container.encodeIfPresent(embedImages, forKey: .embedImages)
            try container.encodeIfPresent(embedVideos, forKey: .embedVideos)
            try container.encodeIfPresent(embedExternals, forKey: .embedExternals)
            try container.encodeIfPresent(embedRecords, forKey: .embedRecords)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(text)
            if let value = labels {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = embedImages {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = embedVideos {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = embedExternals {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = embedRecords {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if text != other.text {
                return false
            }
            if labels != other.labels {
                return false
            }
            if embedImages != other.embedImages {
                return false
            }
            if embedVideos != other.embedVideos {
                return false
            }
            if embedExternals != other.embedExternals {
                return false
            }
            if embedRecords != other.embedRecords {
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
            let textValue = try text.toCBORValue()
            map = map.adding(key: "text", value: textValue)
            if let value = labels {
                let labelsValue = try value.toCBORValue()
                map = map.adding(key: "labels", value: labelsValue)
            }
            if let value = embedImages {
                let embedImagesValue = try value.toCBORValue()
                map = map.adding(key: "embedImages", value: embedImagesValue)
            }
            if let value = embedVideos {
                let embedVideosValue = try value.toCBORValue()
                map = map.adding(key: "embedVideos", value: embedVideosValue)
            }
            if let value = embedExternals {
                let embedExternalsValue = try value.toCBORValue()
                map = map.adding(key: "embedExternals", value: embedExternalsValue)
            }
            if let value = embedRecords {
                let embedRecordsValue = try value.toCBORValue()
                map = map.adding(key: "embedRecords", value: embedRecordsValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case text
            case labels
            case embedImages
            case embedVideos
            case embedExternals
            case embedRecords
        }
    }

    public struct DraftView: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.draft.defs#draftView"
        public let id: TID
        public let draft: Draft
        public let createdAt: ATProtocolDate
        public let updatedAt: ATProtocolDate

        public init(
            id: TID, draft: Draft, createdAt: ATProtocolDate, updatedAt: ATProtocolDate
        ) {
            self.id = id
            self.draft = draft
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                id = try container.decode(TID.self, forKey: .id)
            } catch {
                LogManager.logError("Decoding error for required property 'id': \(error)")
                throw error
            }
            do {
                draft = try container.decode(Draft.self, forKey: .draft)
            } catch {
                LogManager.logError("Decoding error for required property 'draft': \(error)")
                throw error
            }
            do {
                createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
            } catch {
                LogManager.logError("Decoding error for required property 'createdAt': \(error)")
                throw error
            }
            do {
                updatedAt = try container.decode(ATProtocolDate.self, forKey: .updatedAt)
            } catch {
                LogManager.logError("Decoding error for required property 'updatedAt': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(id, forKey: .id)
            try container.encode(draft, forKey: .draft)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encode(updatedAt, forKey: .updatedAt)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(draft)
            hasher.combine(createdAt)
            hasher.combine(updatedAt)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if id != other.id {
                return false
            }
            if draft != other.draft {
                return false
            }
            if createdAt != other.createdAt {
                return false
            }
            if updatedAt != other.updatedAt {
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
            let idValue = try id.toCBORValue()
            map = map.adding(key: "id", value: idValue)
            let draftValue = try draft.toCBORValue()
            map = map.adding(key: "draft", value: draftValue)
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            let updatedAtValue = try updatedAt.toCBORValue()
            map = map.adding(key: "updatedAt", value: updatedAtValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case id
            case draft
            case createdAt
            case updatedAt
        }
    }

    public struct DraftEmbedLocalRef: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.draft.defs#draftEmbedLocalRef"
        public let path: String

        public init(
            path: String
        ) {
            self.path = path
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                path = try container.decode(String.self, forKey: .path)
            } catch {
                LogManager.logError("Decoding error for required property 'path': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(path, forKey: .path)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(path)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if path != other.path {
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
            let pathValue = try path.toCBORValue()
            map = map.adding(key: "path", value: pathValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case path
        }
    }

    public struct DraftEmbedCaption: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.draft.defs#draftEmbedCaption"
        public let lang: LanguageCodeContainer
        public let content: String

        public init(
            lang: LanguageCodeContainer, content: String
        ) {
            self.lang = lang
            self.content = content
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
                content = try container.decode(String.self, forKey: .content)
            } catch {
                LogManager.logError("Decoding error for required property 'content': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(lang, forKey: .lang)
            try container.encode(content, forKey: .content)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(lang)
            hasher.combine(content)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if lang != other.lang {
                return false
            }
            if content != other.content {
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
            let contentValue = try content.toCBORValue()
            map = map.adding(key: "content", value: contentValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case lang
            case content
        }
    }

    public struct DraftEmbedImage: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.draft.defs#draftEmbedImage"
        public let localRef: DraftEmbedLocalRef
        public let alt: String?

        public init(
            localRef: DraftEmbedLocalRef, alt: String?
        ) {
            self.localRef = localRef
            self.alt = alt
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                localRef = try container.decode(DraftEmbedLocalRef.self, forKey: .localRef)
            } catch {
                LogManager.logError("Decoding error for required property 'localRef': \(error)")
                throw error
            }
            do {
                alt = try container.decodeIfPresent(String.self, forKey: .alt)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'alt': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(localRef, forKey: .localRef)
            try container.encodeIfPresent(alt, forKey: .alt)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(localRef)
            if let value = alt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if localRef != other.localRef {
                return false
            }
            if alt != other.alt {
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
            let localRefValue = try localRef.toCBORValue()
            map = map.adding(key: "localRef", value: localRefValue)
            if let value = alt {
                let altValue = try value.toCBORValue()
                map = map.adding(key: "alt", value: altValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case localRef
            case alt
        }
    }

    public struct DraftEmbedVideo: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.draft.defs#draftEmbedVideo"
        public let localRef: DraftEmbedLocalRef
        public let alt: String?
        public let captions: [DraftEmbedCaption]?

        public init(
            localRef: DraftEmbedLocalRef, alt: String?, captions: [DraftEmbedCaption]?
        ) {
            self.localRef = localRef
            self.alt = alt
            self.captions = captions
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                localRef = try container.decode(DraftEmbedLocalRef.self, forKey: .localRef)
            } catch {
                LogManager.logError("Decoding error for required property 'localRef': \(error)")
                throw error
            }
            do {
                alt = try container.decodeIfPresent(String.self, forKey: .alt)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'alt': \(error)")
                throw error
            }
            do {
                captions = try container.decodeIfPresent([DraftEmbedCaption].self, forKey: .captions)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'captions': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(localRef, forKey: .localRef)
            try container.encodeIfPresent(alt, forKey: .alt)
            try container.encodeIfPresent(captions, forKey: .captions)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(localRef)
            if let value = alt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = captions {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if localRef != other.localRef {
                return false
            }
            if alt != other.alt {
                return false
            }
            if captions != other.captions {
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
            let localRefValue = try localRef.toCBORValue()
            map = map.adding(key: "localRef", value: localRefValue)
            if let value = alt {
                let altValue = try value.toCBORValue()
                map = map.adding(key: "alt", value: altValue)
            }
            if let value = captions {
                let captionsValue = try value.toCBORValue()
                map = map.adding(key: "captions", value: captionsValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case localRef
            case alt
            case captions
        }
    }

    public struct DraftEmbedExternal: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.draft.defs#draftEmbedExternal"
        public let uri: URI

        public init(
            uri: URI
        ) {
            self.uri = uri
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                uri = try container.decode(URI.self, forKey: .uri)
            } catch {
                LogManager.logError("Decoding error for required property 'uri': \(error)")
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

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let uriValue = try uri.toCBORValue()
            map = map.adding(key: "uri", value: uriValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
        }
    }

    public struct DraftEmbedRecord: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.draft.defs#draftEmbedRecord"
        public let record: ComAtprotoRepoStrongRef

        public init(
            record: ComAtprotoRepoStrongRef
        ) {
            self.record = record
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                record = try container.decode(ComAtprotoRepoStrongRef.self, forKey: .record)
            } catch {
                LogManager.logError("Decoding error for required property 'record': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(record, forKey: .record)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(record)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if record != other.record {
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
            let recordValue = try record.toCBORValue()
            map = map.adding(key: "record", value: recordValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case record
        }
    }

    public enum DraftPostgateEmbeddingRulesUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case appBskyFeedPostgateDisableRule(AppBskyFeedPostgate.DisableRule)
        case unexpected(ATProtocolValueContainer)
        public init(_ value: AppBskyFeedPostgate.DisableRule) {
            self = .appBskyFeedPostgateDisableRule(value)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            switch typeValue {
            case "app.bsky.feed.postgate#disableRule":
                let value = try AppBskyFeedPostgate.DisableRule(from: decoder)
                self = .appBskyFeedPostgateDisableRule(value)
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .appBskyFeedPostgateDisableRule(value):
                try container.encode("app.bsky.feed.postgate#disableRule", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .appBskyFeedPostgateDisableRule(value):
                hasher.combine("app.bsky.feed.postgate#disableRule")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: DraftPostgateEmbeddingRulesUnion, rhs: DraftPostgateEmbeddingRulesUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .appBskyFeedPostgateDisableRule(lhsValue),
                .appBskyFeedPostgateDisableRule(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? DraftPostgateEmbeddingRulesUnion else { return false }
            return self == other
        }

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .appBskyFeedPostgateDisableRule(value):
                map = map.adding(key: "$type", value: "app.bsky.feed.postgate#disableRule")

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

    public enum DraftThreadgateAllowUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case appBskyFeedThreadgateMentionRule(AppBskyFeedThreadgate.MentionRule)
        case appBskyFeedThreadgateFollowerRule(AppBskyFeedThreadgate.FollowerRule)
        case appBskyFeedThreadgateFollowingRule(AppBskyFeedThreadgate.FollowingRule)
        case appBskyFeedThreadgateListRule(AppBskyFeedThreadgate.ListRule)
        case unexpected(ATProtocolValueContainer)
        public init(_ value: AppBskyFeedThreadgate.MentionRule) {
            self = .appBskyFeedThreadgateMentionRule(value)
        }

        public init(_ value: AppBskyFeedThreadgate.FollowerRule) {
            self = .appBskyFeedThreadgateFollowerRule(value)
        }

        public init(_ value: AppBskyFeedThreadgate.FollowingRule) {
            self = .appBskyFeedThreadgateFollowingRule(value)
        }

        public init(_ value: AppBskyFeedThreadgate.ListRule) {
            self = .appBskyFeedThreadgateListRule(value)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            switch typeValue {
            case "app.bsky.feed.threadgate#mentionRule":
                let value = try AppBskyFeedThreadgate.MentionRule(from: decoder)
                self = .appBskyFeedThreadgateMentionRule(value)
            case "app.bsky.feed.threadgate#followerRule":
                let value = try AppBskyFeedThreadgate.FollowerRule(from: decoder)
                self = .appBskyFeedThreadgateFollowerRule(value)
            case "app.bsky.feed.threadgate#followingRule":
                let value = try AppBskyFeedThreadgate.FollowingRule(from: decoder)
                self = .appBskyFeedThreadgateFollowingRule(value)
            case "app.bsky.feed.threadgate#listRule":
                let value = try AppBskyFeedThreadgate.ListRule(from: decoder)
                self = .appBskyFeedThreadgateListRule(value)
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .appBskyFeedThreadgateMentionRule(value):
                try container.encode("app.bsky.feed.threadgate#mentionRule", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyFeedThreadgateFollowerRule(value):
                try container.encode("app.bsky.feed.threadgate#followerRule", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyFeedThreadgateFollowingRule(value):
                try container.encode("app.bsky.feed.threadgate#followingRule", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyFeedThreadgateListRule(value):
                try container.encode("app.bsky.feed.threadgate#listRule", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .appBskyFeedThreadgateMentionRule(value):
                hasher.combine("app.bsky.feed.threadgate#mentionRule")
                hasher.combine(value)
            case let .appBskyFeedThreadgateFollowerRule(value):
                hasher.combine("app.bsky.feed.threadgate#followerRule")
                hasher.combine(value)
            case let .appBskyFeedThreadgateFollowingRule(value):
                hasher.combine("app.bsky.feed.threadgate#followingRule")
                hasher.combine(value)
            case let .appBskyFeedThreadgateListRule(value):
                hasher.combine("app.bsky.feed.threadgate#listRule")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: DraftThreadgateAllowUnion, rhs: DraftThreadgateAllowUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .appBskyFeedThreadgateMentionRule(lhsValue),
                .appBskyFeedThreadgateMentionRule(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyFeedThreadgateFollowerRule(lhsValue),
                .appBskyFeedThreadgateFollowerRule(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyFeedThreadgateFollowingRule(lhsValue),
                .appBskyFeedThreadgateFollowingRule(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyFeedThreadgateListRule(lhsValue),
                .appBskyFeedThreadgateListRule(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? DraftThreadgateAllowUnion else { return false }
            return self == other
        }

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .appBskyFeedThreadgateMentionRule(value):
                map = map.adding(key: "$type", value: "app.bsky.feed.threadgate#mentionRule")

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
            case let .appBskyFeedThreadgateFollowerRule(value):
                map = map.adding(key: "$type", value: "app.bsky.feed.threadgate#followerRule")

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
            case let .appBskyFeedThreadgateFollowingRule(value):
                map = map.adding(key: "$type", value: "app.bsky.feed.threadgate#followingRule")

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
            case let .appBskyFeedThreadgateListRule(value):
                map = map.adding(key: "$type", value: "app.bsky.feed.threadgate#listRule")

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

    public enum DraftPostLabelsUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case comAtprotoLabelDefsSelfLabels(ComAtprotoLabelDefs.SelfLabels)
        case unexpected(ATProtocolValueContainer)
        public init(_ value: ComAtprotoLabelDefs.SelfLabels) {
            self = .comAtprotoLabelDefsSelfLabels(value)
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

        public static func == (lhs: DraftPostLabelsUnion, rhs: DraftPostLabelsUnion) -> Bool {
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
            guard let other = other as? DraftPostLabelsUnion else { return false }
            return self == other
        }

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .comAtprotoLabelDefsSelfLabels(value):
                map = map.adding(key: "$type", value: "com.atproto.label.defs#selfLabels")

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
