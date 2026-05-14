import Foundation



// lexicon: 1, id: place.stream.livestream


public struct PlaceStreamLivestream: ATProtocolCodable, ATProtocolValue { 

    public static let typeIdentifier = "place.stream.livestream"
        public let title: String
        public let url: URI?
        public let createdAt: ATProtocolDate
        public let lastSeenAt: ATProtocolDate?
        public let endedAt: ATProtocolDate?
        public let idleTimeoutSeconds: Int?
        public let post: ComAtprotoRepoStrongRef?
        public let agent: String?
        public let canonicalUrl: URI?
        public let thumb: Blob?
        public let notificationSettings: PlaceStreamLivestream.NotificationSettings?

        public init(title: String, url: URI?, createdAt: ATProtocolDate, lastSeenAt: ATProtocolDate?, endedAt: ATProtocolDate?, idleTimeoutSeconds: Int?, post: ComAtprotoRepoStrongRef?, agent: String?, canonicalUrl: URI?, thumb: Blob?, notificationSettings: PlaceStreamLivestream.NotificationSettings?) {
            self.title = title
            self.url = url
            self.createdAt = createdAt
            self.lastSeenAt = lastSeenAt
            self.endedAt = endedAt
            self.idleTimeoutSeconds = idleTimeoutSeconds
            self.post = post
            self.agent = agent
            self.canonicalUrl = canonicalUrl
            self.thumb = thumb
            self.notificationSettings = notificationSettings
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.title = try container.decode(String.self, forKey: .title)
            self.url = try container.decodeIfPresent(URI.self, forKey: .url)
            self.createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
            self.lastSeenAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .lastSeenAt)
            self.endedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .endedAt)
            self.idleTimeoutSeconds = try container.decodeIfPresent(Int.self, forKey: .idleTimeoutSeconds)
            self.post = try container.decodeIfPresent(ComAtprotoRepoStrongRef.self, forKey: .post)
            self.agent = try container.decodeIfPresent(String.self, forKey: .agent)
            self.canonicalUrl = try container.decodeIfPresent(URI.self, forKey: .canonicalUrl)
            self.thumb = try container.decodeIfPresent(Blob.self, forKey: .thumb)
            self.notificationSettings = try container.decodeIfPresent(PlaceStreamLivestream.NotificationSettings.self, forKey: .notificationSettings)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(title, forKey: .title)
            try container.encodeIfPresent(url, forKey: .url)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encodeIfPresent(lastSeenAt, forKey: .lastSeenAt)
            try container.encodeIfPresent(endedAt, forKey: .endedAt)
            try container.encodeIfPresent(idleTimeoutSeconds, forKey: .idleTimeoutSeconds)
            try container.encodeIfPresent(post, forKey: .post)
            try container.encodeIfPresent(agent, forKey: .agent)
            try container.encodeIfPresent(canonicalUrl, forKey: .canonicalUrl)
            try container.encodeIfPresent(thumb, forKey: .thumb)
            try container.encodeIfPresent(notificationSettings, forKey: .notificationSettings)
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if title != other.title {
                return false
            }
            if url != other.url {
                return false
            }
            if createdAt != other.createdAt {
                return false
            }
            if lastSeenAt != other.lastSeenAt {
                return false
            }
            if endedAt != other.endedAt {
                return false
            }
            if idleTimeoutSeconds != other.idleTimeoutSeconds {
                return false
            }
            if post != other.post {
                return false
            }
            if agent != other.agent {
                return false
            }
            if canonicalUrl != other.canonicalUrl {
                return false
            }
            if thumb != other.thumb {
                return false
            }
            if notificationSettings != other.notificationSettings {
                return false
            }
            return true
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(title)
            if let value = url {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(createdAt)
            if let value = lastSeenAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = endedAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = idleTimeoutSeconds {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = post {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = agent {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = canonicalUrl {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = thumb {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = notificationSettings {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let titleValue = try title.toCBORValue()
            map = map.adding(key: "title", value: titleValue)
            if let value = url {
                let urlValue = try value.toCBORValue()
                map = map.adding(key: "url", value: urlValue)
            }
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            if let value = lastSeenAt {
                let lastSeenAtValue = try value.toCBORValue()
                map = map.adding(key: "lastSeenAt", value: lastSeenAtValue)
            }
            if let value = endedAt {
                let endedAtValue = try value.toCBORValue()
                map = map.adding(key: "endedAt", value: endedAtValue)
            }
            if let value = idleTimeoutSeconds {
                let idleTimeoutSecondsValue = try value.toCBORValue()
                map = map.adding(key: "idleTimeoutSeconds", value: idleTimeoutSecondsValue)
            }
            if let value = post {
                let postValue = try value.toCBORValue()
                map = map.adding(key: "post", value: postValue)
            }
            if let value = agent {
                let agentValue = try value.toCBORValue()
                map = map.adding(key: "agent", value: agentValue)
            }
            if let value = canonicalUrl {
                let canonicalUrlValue = try value.toCBORValue()
                map = map.adding(key: "canonicalUrl", value: canonicalUrlValue)
            }
            if let value = thumb {
                let thumbValue = try value.toCBORValue()
                map = map.adding(key: "thumb", value: thumbValue)
            }
            if let value = notificationSettings {
                let notificationSettingsValue = try value.toCBORValue()
                map = map.adding(key: "notificationSettings", value: notificationSettingsValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case title
            case url
            case createdAt
            case lastSeenAt
            case endedAt
            case idleTimeoutSeconds
            case post
            case agent
            case canonicalUrl
            case thumb
            case notificationSettings
        }
        
public struct NotificationSettings: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "place.stream.livestream#notificationSettings"
            public let pushNotification: Bool?

        public init(
            pushNotification: Bool?
        ) {
            self.pushNotification = pushNotification
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.pushNotification = try container.decodeIfPresent(Bool.self, forKey: .pushNotification)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'pushNotification': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encodeIfPresent(pushNotification, forKey: .pushNotification)
        }

        public func hash(into hasher: inout Hasher) {
            if let value = pushNotification {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if pushNotification != other.pushNotification {
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
            if let value = pushNotification {
                let pushNotificationValue = try value.toCBORValue()
                map = map.adding(key: "pushNotification", value: pushNotificationValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case pushNotification
        }
    }
        
public struct LivestreamView: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "place.stream.livestream#livestreamView"
            public let uri: ATProtocolURI
            public let cid: CID
            public let author: AppBskyActorDefs.ProfileViewBasic
            public let record: ATProtocolValueContainer
            public let indexedAt: ATProtocolDate
            public let viewerCount: ViewerCount?

        public init(
            uri: ATProtocolURI, cid: CID, author: AppBskyActorDefs.ProfileViewBasic, record: ATProtocolValueContainer, indexedAt: ATProtocolDate, viewerCount: ViewerCount?
        ) {
            self.uri = uri
            self.cid = cid
            self.author = author
            self.record = record
            self.indexedAt = indexedAt
            self.viewerCount = viewerCount
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.uri = try container.decode(ATProtocolURI.self, forKey: .uri)
            } catch {
                LogManager.logError("Decoding error for required property 'uri': \(error)")
                throw error
            }
            do {
                self.cid = try container.decode(CID.self, forKey: .cid)
            } catch {
                LogManager.logError("Decoding error for required property 'cid': \(error)")
                throw error
            }
            do {
                self.author = try container.decode(AppBskyActorDefs.ProfileViewBasic.self, forKey: .author)
            } catch {
                LogManager.logError("Decoding error for required property 'author': \(error)")
                throw error
            }
            do {
                self.record = try container.decode(ATProtocolValueContainer.self, forKey: .record)
            } catch {
                LogManager.logError("Decoding error for required property 'record': \(error)")
                throw error
            }
            do {
                self.indexedAt = try container.decode(ATProtocolDate.self, forKey: .indexedAt)
            } catch {
                LogManager.logError("Decoding error for required property 'indexedAt': \(error)")
                throw error
            }
            do {
                self.viewerCount = try container.decodeIfPresent(ViewerCount.self, forKey: .viewerCount)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'viewerCount': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(uri, forKey: .uri)
            try container.encode(cid, forKey: .cid)
            try container.encode(author, forKey: .author)
            try container.encode(record, forKey: .record)
            try container.encode(indexedAt, forKey: .indexedAt)
            try container.encodeIfPresent(viewerCount, forKey: .viewerCount)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
            hasher.combine(cid)
            hasher.combine(author)
            hasher.combine(record)
            hasher.combine(indexedAt)
            if let value = viewerCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if uri != other.uri {
                return false
            }
            if cid != other.cid {
                return false
            }
            if author != other.author {
                return false
            }
            if record != other.record {
                return false
            }
            if indexedAt != other.indexedAt {
                return false
            }
            if viewerCount != other.viewerCount {
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
            let cidValue = try cid.toCBORValue()
            map = map.adding(key: "cid", value: cidValue)
            let authorValue = try author.toCBORValue()
            map = map.adding(key: "author", value: authorValue)
            let recordValue = try record.toCBORValue()
            map = map.adding(key: "record", value: recordValue)
            let indexedAtValue = try indexedAt.toCBORValue()
            map = map.adding(key: "indexedAt", value: indexedAtValue)
            if let value = viewerCount {
                let viewerCountValue = try value.toCBORValue()
                map = map.adding(key: "viewerCount", value: viewerCountValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
            case cid
            case author
            case record
            case indexedAt
            case viewerCount
        }
    }
        
public struct ViewerCount: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "place.stream.livestream#viewerCount"
            public let count: Int

        public init(
            count: Int
        ) {
            self.count = count
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.count = try container.decode(Int.self, forKey: .count)
            } catch {
                LogManager.logError("Decoding error for required property 'count': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(count, forKey: .count)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(count)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if count != other.count {
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
            let countValue = try count.toCBORValue()
            map = map.adding(key: "count", value: countValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case count
        }
    }
        
public struct TeleportArrival: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "place.stream.livestream#teleportArrival"
            public let teleportUri: ATProtocolURI
            public let source: AppBskyActorDefs.ProfileViewBasic
            public let chatProfile: PlaceStreamChatProfile?
            public let viewerCount: Int
            public let startsAt: ATProtocolDate

        public init(
            teleportUri: ATProtocolURI, source: AppBskyActorDefs.ProfileViewBasic, chatProfile: PlaceStreamChatProfile?, viewerCount: Int, startsAt: ATProtocolDate
        ) {
            self.teleportUri = teleportUri
            self.source = source
            self.chatProfile = chatProfile
            self.viewerCount = viewerCount
            self.startsAt = startsAt
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.teleportUri = try container.decode(ATProtocolURI.self, forKey: .teleportUri)
            } catch {
                LogManager.logError("Decoding error for required property 'teleportUri': \(error)")
                throw error
            }
            do {
                self.source = try container.decode(AppBskyActorDefs.ProfileViewBasic.self, forKey: .source)
            } catch {
                LogManager.logError("Decoding error for required property 'source': \(error)")
                throw error
            }
            do {
                self.chatProfile = try container.decodeIfPresent(PlaceStreamChatProfile.self, forKey: .chatProfile)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'chatProfile': \(error)")
                throw error
            }
            do {
                self.viewerCount = try container.decode(Int.self, forKey: .viewerCount)
            } catch {
                LogManager.logError("Decoding error for required property 'viewerCount': \(error)")
                throw error
            }
            do {
                self.startsAt = try container.decode(ATProtocolDate.self, forKey: .startsAt)
            } catch {
                LogManager.logError("Decoding error for required property 'startsAt': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(teleportUri, forKey: .teleportUri)
            try container.encode(source, forKey: .source)
            try container.encodeIfPresent(chatProfile, forKey: .chatProfile)
            try container.encode(viewerCount, forKey: .viewerCount)
            try container.encode(startsAt, forKey: .startsAt)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(teleportUri)
            hasher.combine(source)
            if let value = chatProfile {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(viewerCount)
            hasher.combine(startsAt)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if teleportUri != other.teleportUri {
                return false
            }
            if source != other.source {
                return false
            }
            if chatProfile != other.chatProfile {
                return false
            }
            if viewerCount != other.viewerCount {
                return false
            }
            if startsAt != other.startsAt {
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
            let teleportUriValue = try teleportUri.toCBORValue()
            map = map.adding(key: "teleportUri", value: teleportUriValue)
            let sourceValue = try source.toCBORValue()
            map = map.adding(key: "source", value: sourceValue)
            if let value = chatProfile {
                let chatProfileValue = try value.toCBORValue()
                map = map.adding(key: "chatProfile", value: chatProfileValue)
            }
            let viewerCountValue = try viewerCount.toCBORValue()
            map = map.adding(key: "viewerCount", value: viewerCountValue)
            let startsAtValue = try startsAt.toCBORValue()
            map = map.adding(key: "startsAt", value: startsAtValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case teleportUri
            case source
            case chatProfile
            case viewerCount
            case startsAt
        }
    }
        
public struct TeleportCanceled: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "place.stream.livestream#teleportCanceled"
            public let teleportUri: ATProtocolURI
            public let reason: String

        public init(
            teleportUri: ATProtocolURI, reason: String
        ) {
            self.teleportUri = teleportUri
            self.reason = reason
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.teleportUri = try container.decode(ATProtocolURI.self, forKey: .teleportUri)
            } catch {
                LogManager.logError("Decoding error for required property 'teleportUri': \(error)")
                throw error
            }
            do {
                self.reason = try container.decode(String.self, forKey: .reason)
            } catch {
                LogManager.logError("Decoding error for required property 'reason': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(teleportUri, forKey: .teleportUri)
            try container.encode(reason, forKey: .reason)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(teleportUri)
            hasher.combine(reason)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if teleportUri != other.teleportUri {
                return false
            }
            if reason != other.reason {
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
            let teleportUriValue = try teleportUri.toCBORValue()
            map = map.adding(key: "teleportUri", value: teleportUriValue)
            let reasonValue = try reason.toCBORValue()
            map = map.adding(key: "reason", value: reasonValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case teleportUri
            case reason
        }
    }
        
public struct StreamplaceAnything: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "place.stream.livestream#streamplaceAnything"
            public let livestream: StreamplaceAnythingLivestreamUnion

        public init(
            livestream: StreamplaceAnythingLivestreamUnion
        ) {
            self.livestream = livestream
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.livestream = try container.decode(StreamplaceAnythingLivestreamUnion.self, forKey: .livestream)
            } catch {
                LogManager.logError("Decoding error for required property 'livestream': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(livestream, forKey: .livestream)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(livestream)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if livestream != other.livestream {
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
            let livestreamValue = try livestream.toCBORValue()
            map = map.adding(key: "livestream", value: livestreamValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case livestream
        }
    }




public indirect enum StreamplaceAnythingLivestreamUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
    case placeStreamLivestreamLivestreamView(PlaceStreamLivestream.LivestreamView)
    case placeStreamLivestreamViewerCount(PlaceStreamLivestream.ViewerCount)
    case placeStreamLivestreamTeleportArrival(PlaceStreamLivestream.TeleportArrival)
    case placeStreamLivestreamTeleportCanceled(PlaceStreamLivestream.TeleportCanceled)
    case placeStreamDefsBlockView(PlaceStreamDefs.BlockView)
    case placeStreamDefsRenditions(PlaceStreamDefs.Renditions)
    case placeStreamDefsRendition(PlaceStreamDefs.Rendition)
    case placeStreamChatDefsMessageView(PlaceStreamChatDefs.MessageView)
    case placeStreamChatDefsPinnedRecordView(PlaceStreamChatDefs.PinnedRecordView)
    case unexpected(ATProtocolValueContainer)
    public init(_ value: PlaceStreamLivestream.LivestreamView) {
        self = .placeStreamLivestreamLivestreamView(value)
    }
    public init(_ value: PlaceStreamLivestream.ViewerCount) {
        self = .placeStreamLivestreamViewerCount(value)
    }
    public init(_ value: PlaceStreamLivestream.TeleportArrival) {
        self = .placeStreamLivestreamTeleportArrival(value)
    }
    public init(_ value: PlaceStreamLivestream.TeleportCanceled) {
        self = .placeStreamLivestreamTeleportCanceled(value)
    }
    public init(_ value: PlaceStreamDefs.BlockView) {
        self = .placeStreamDefsBlockView(value)
    }
    public init(_ value: PlaceStreamDefs.Renditions) {
        self = .placeStreamDefsRenditions(value)
    }
    public init(_ value: PlaceStreamDefs.Rendition) {
        self = .placeStreamDefsRendition(value)
    }
    public init(_ value: PlaceStreamChatDefs.MessageView) {
        self = .placeStreamChatDefsMessageView(value)
    }
    public init(_ value: PlaceStreamChatDefs.PinnedRecordView) {
        self = .placeStreamChatDefsPinnedRecordView(value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)

        switch typeValue {
        case "place.stream.livestream#livestreamView":
            let value = try PlaceStreamLivestream.LivestreamView(from: decoder)
            self = .placeStreamLivestreamLivestreamView(value)
        case "place.stream.livestream#viewerCount":
            let value = try PlaceStreamLivestream.ViewerCount(from: decoder)
            self = .placeStreamLivestreamViewerCount(value)
        case "place.stream.livestream#teleportArrival":
            let value = try PlaceStreamLivestream.TeleportArrival(from: decoder)
            self = .placeStreamLivestreamTeleportArrival(value)
        case "place.stream.livestream#teleportCanceled":
            let value = try PlaceStreamLivestream.TeleportCanceled(from: decoder)
            self = .placeStreamLivestreamTeleportCanceled(value)
        case "place.stream.defs#blockView":
            let value = try PlaceStreamDefs.BlockView(from: decoder)
            self = .placeStreamDefsBlockView(value)
        case "place.stream.defs#renditions":
            let value = try PlaceStreamDefs.Renditions(from: decoder)
            self = .placeStreamDefsRenditions(value)
        case "place.stream.defs#rendition":
            let value = try PlaceStreamDefs.Rendition(from: decoder)
            self = .placeStreamDefsRendition(value)
        case "place.stream.chat.defs#messageView":
            let value = try PlaceStreamChatDefs.MessageView(from: decoder)
            self = .placeStreamChatDefsMessageView(value)
        case "place.stream.chat.defs#pinnedRecordView":
            let value = try PlaceStreamChatDefs.PinnedRecordView(from: decoder)
            self = .placeStreamChatDefsPinnedRecordView(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .placeStreamLivestreamLivestreamView(let value):
            try container.encode("place.stream.livestream#livestreamView", forKey: .type)
            try value.encode(to: encoder)
        case .placeStreamLivestreamViewerCount(let value):
            try container.encode("place.stream.livestream#viewerCount", forKey: .type)
            try value.encode(to: encoder)
        case .placeStreamLivestreamTeleportArrival(let value):
            try container.encode("place.stream.livestream#teleportArrival", forKey: .type)
            try value.encode(to: encoder)
        case .placeStreamLivestreamTeleportCanceled(let value):
            try container.encode("place.stream.livestream#teleportCanceled", forKey: .type)
            try value.encode(to: encoder)
        case .placeStreamDefsBlockView(let value):
            try container.encode("place.stream.defs#blockView", forKey: .type)
            try value.encode(to: encoder)
        case .placeStreamDefsRenditions(let value):
            try container.encode("place.stream.defs#renditions", forKey: .type)
            try value.encode(to: encoder)
        case .placeStreamDefsRendition(let value):
            try container.encode("place.stream.defs#rendition", forKey: .type)
            try value.encode(to: encoder)
        case .placeStreamChatDefsMessageView(let value):
            try container.encode("place.stream.chat.defs#messageView", forKey: .type)
            try value.encode(to: encoder)
        case .placeStreamChatDefsPinnedRecordView(let value):
            try container.encode("place.stream.chat.defs#pinnedRecordView", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let container):
            try container.encode(to: encoder)
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .placeStreamLivestreamLivestreamView(let value):
            hasher.combine("place.stream.livestream#livestreamView")
            hasher.combine(value)
        case .placeStreamLivestreamViewerCount(let value):
            hasher.combine("place.stream.livestream#viewerCount")
            hasher.combine(value)
        case .placeStreamLivestreamTeleportArrival(let value):
            hasher.combine("place.stream.livestream#teleportArrival")
            hasher.combine(value)
        case .placeStreamLivestreamTeleportCanceled(let value):
            hasher.combine("place.stream.livestream#teleportCanceled")
            hasher.combine(value)
        case .placeStreamDefsBlockView(let value):
            hasher.combine("place.stream.defs#blockView")
            hasher.combine(value)
        case .placeStreamDefsRenditions(let value):
            hasher.combine("place.stream.defs#renditions")
            hasher.combine(value)
        case .placeStreamDefsRendition(let value):
            hasher.combine("place.stream.defs#rendition")
            hasher.combine(value)
        case .placeStreamChatDefsMessageView(let value):
            hasher.combine("place.stream.chat.defs#messageView")
            hasher.combine(value)
        case .placeStreamChatDefsPinnedRecordView(let value):
            hasher.combine("place.stream.chat.defs#pinnedRecordView")
            hasher.combine(value)
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: StreamplaceAnythingLivestreamUnion, rhs: StreamplaceAnythingLivestreamUnion) -> Bool {
        switch (lhs, rhs) {
        case (.placeStreamLivestreamLivestreamView(let lhsValue),
              .placeStreamLivestreamLivestreamView(let rhsValue)):
            return lhsValue == rhsValue
        case (.placeStreamLivestreamViewerCount(let lhsValue),
              .placeStreamLivestreamViewerCount(let rhsValue)):
            return lhsValue == rhsValue
        case (.placeStreamLivestreamTeleportArrival(let lhsValue),
              .placeStreamLivestreamTeleportArrival(let rhsValue)):
            return lhsValue == rhsValue
        case (.placeStreamLivestreamTeleportCanceled(let lhsValue),
              .placeStreamLivestreamTeleportCanceled(let rhsValue)):
            return lhsValue == rhsValue
        case (.placeStreamDefsBlockView(let lhsValue),
              .placeStreamDefsBlockView(let rhsValue)):
            return lhsValue == rhsValue
        case (.placeStreamDefsRenditions(let lhsValue),
              .placeStreamDefsRenditions(let rhsValue)):
            return lhsValue == rhsValue
        case (.placeStreamDefsRendition(let lhsValue),
              .placeStreamDefsRendition(let rhsValue)):
            return lhsValue == rhsValue
        case (.placeStreamChatDefsMessageView(let lhsValue),
              .placeStreamChatDefsMessageView(let rhsValue)):
            return lhsValue == rhsValue
        case (.placeStreamChatDefsPinnedRecordView(let lhsValue),
              .placeStreamChatDefsPinnedRecordView(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? StreamplaceAnythingLivestreamUnion else { return false }
        return self == other
    }
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        // Create an ordered map to maintain field order
        var map = OrderedCBORMap()
        
        switch self {
        case .placeStreamLivestreamLivestreamView(let value):
            map = map.adding(key: "$type", value: "place.stream.livestream#livestreamView")
            
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
        case .placeStreamLivestreamViewerCount(let value):
            map = map.adding(key: "$type", value: "place.stream.livestream#viewerCount")
            
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
        case .placeStreamLivestreamTeleportArrival(let value):
            map = map.adding(key: "$type", value: "place.stream.livestream#teleportArrival")
            
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
        case .placeStreamLivestreamTeleportCanceled(let value):
            map = map.adding(key: "$type", value: "place.stream.livestream#teleportCanceled")
            
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
        case .placeStreamDefsBlockView(let value):
            map = map.adding(key: "$type", value: "place.stream.defs#blockView")
            
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
        case .placeStreamDefsRenditions(let value):
            map = map.adding(key: "$type", value: "place.stream.defs#renditions")
            
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
        case .placeStreamDefsRendition(let value):
            map = map.adding(key: "$type", value: "place.stream.defs#rendition")
            
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
        case .placeStreamChatDefsMessageView(let value):
            map = map.adding(key: "$type", value: "place.stream.chat.defs#messageView")
            
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
        case .placeStreamChatDefsPinnedRecordView(let value):
            map = map.adding(key: "$type", value: "place.stream.chat.defs#pinnedRecordView")
            
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


                           

