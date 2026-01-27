import Foundation

// lexicon: 1, id: blue.catbird.mls.message.defs

public enum BlueCatbirdMlsMessageDefs {
    public static let typeIdentifier = "blue.catbird.mls.message.defs"

    public struct PayloadView: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "blue.catbird.mls.message.defs#payloadView"
        public let version: Int
        public let messageType: String
        public let text: String?
        public let embed: PayloadViewEmbedUnion?
        public let adminRoster: AdminRoster?
        public let adminAction: AdminAction?
        public let reaction: ReactionPayload?
        public let readReceipt: ReadReceiptPayload?
        public let typing: TypingPayload?

        public init(
            version: Int, messageType: String, text: String?, embed: PayloadViewEmbedUnion?, adminRoster: AdminRoster?, adminAction: AdminAction?, reaction: ReactionPayload?, readReceipt: ReadReceiptPayload?, typing: TypingPayload?
        ) {
            self.version = version
            self.messageType = messageType
            self.text = text
            self.embed = embed
            self.adminRoster = adminRoster
            self.adminAction = adminAction
            self.reaction = reaction
            self.readReceipt = readReceipt
            self.typing = typing
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                version = try container.decode(Int.self, forKey: .version)
            } catch {
                LogManager.logError("Decoding error for required property 'version': \(error)")
                throw error
            }
            do {
                messageType = try container.decode(String.self, forKey: .messageType)
            } catch {
                LogManager.logError("Decoding error for required property 'messageType': \(error)")
                throw error
            }
            do {
                text = try container.decodeIfPresent(String.self, forKey: .text)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'text': \(error)")
                throw error
            }
            do {
                embed = try container.decodeIfPresent(PayloadViewEmbedUnion.self, forKey: .embed)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'embed': \(error)")
                throw error
            }
            do {
                adminRoster = try container.decodeIfPresent(AdminRoster.self, forKey: .adminRoster)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'adminRoster': \(error)")
                throw error
            }
            do {
                adminAction = try container.decodeIfPresent(AdminAction.self, forKey: .adminAction)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'adminAction': \(error)")
                throw error
            }
            do {
                reaction = try container.decodeIfPresent(ReactionPayload.self, forKey: .reaction)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'reaction': \(error)")
                throw error
            }
            do {
                readReceipt = try container.decodeIfPresent(ReadReceiptPayload.self, forKey: .readReceipt)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'readReceipt': \(error)")
                throw error
            }
            do {
                typing = try container.decodeIfPresent(TypingPayload.self, forKey: .typing)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'typing': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(version, forKey: .version)
            try container.encode(messageType, forKey: .messageType)
            try container.encodeIfPresent(text, forKey: .text)
            try container.encodeIfPresent(embed, forKey: .embed)
            try container.encodeIfPresent(adminRoster, forKey: .adminRoster)
            try container.encodeIfPresent(adminAction, forKey: .adminAction)
            try container.encodeIfPresent(reaction, forKey: .reaction)
            try container.encodeIfPresent(readReceipt, forKey: .readReceipt)
            try container.encodeIfPresent(typing, forKey: .typing)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(version)
            hasher.combine(messageType)
            if let value = text {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = embed {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = adminRoster {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = adminAction {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = reaction {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = readReceipt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = typing {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if version != other.version {
                return false
            }
            if messageType != other.messageType {
                return false
            }
            if text != other.text {
                return false
            }
            if embed != other.embed {
                return false
            }
            if adminRoster != other.adminRoster {
                return false
            }
            if adminAction != other.adminAction {
                return false
            }
            if reaction != other.reaction {
                return false
            }
            if readReceipt != other.readReceipt {
                return false
            }
            if typing != other.typing {
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
            let versionValue = try version.toCBORValue()
            map = map.adding(key: "version", value: versionValue)
            let messageTypeValue = try messageType.toCBORValue()
            map = map.adding(key: "messageType", value: messageTypeValue)
            if let value = text {
                let textValue = try value.toCBORValue()
                map = map.adding(key: "text", value: textValue)
            }
            if let value = embed {
                let embedValue = try value.toCBORValue()
                map = map.adding(key: "embed", value: embedValue)
            }
            if let value = adminRoster {
                let adminRosterValue = try value.toCBORValue()
                map = map.adding(key: "adminRoster", value: adminRosterValue)
            }
            if let value = adminAction {
                let adminActionValue = try value.toCBORValue()
                map = map.adding(key: "adminAction", value: adminActionValue)
            }
            if let value = reaction {
                let reactionValue = try value.toCBORValue()
                map = map.adding(key: "reaction", value: reactionValue)
            }
            if let value = readReceipt {
                let readReceiptValue = try value.toCBORValue()
                map = map.adding(key: "readReceipt", value: readReceiptValue)
            }
            if let value = typing {
                let typingValue = try value.toCBORValue()
                map = map.adding(key: "typing", value: typingValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case version
            case messageType
            case text
            case embed
            case adminRoster
            case adminAction
            case reaction
            case readReceipt
            case typing
        }
    }

    public struct RecordEmbed: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "blue.catbird.mls.message.defs#recordEmbed"
        public let uri: ATProtocolURI
        public let cid: CID?
        public let authorDid: DID
        public let previewText: String?
        public let createdAt: ATProtocolDate?

        public init(
            uri: ATProtocolURI, cid: CID?, authorDid: DID, previewText: String?, createdAt: ATProtocolDate?
        ) {
            self.uri = uri
            self.cid = cid
            self.authorDid = authorDid
            self.previewText = previewText
            self.createdAt = createdAt
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                uri = try container.decode(ATProtocolURI.self, forKey: .uri)
            } catch {
                LogManager.logError("Decoding error for required property 'uri': \(error)")
                throw error
            }
            do {
                cid = try container.decodeIfPresent(CID.self, forKey: .cid)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'cid': \(error)")
                throw error
            }
            do {
                authorDid = try container.decode(DID.self, forKey: .authorDid)
            } catch {
                LogManager.logError("Decoding error for required property 'authorDid': \(error)")
                throw error
            }
            do {
                previewText = try container.decodeIfPresent(String.self, forKey: .previewText)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'previewText': \(error)")
                throw error
            }
            do {
                createdAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .createdAt)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'createdAt': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(uri, forKey: .uri)
            try container.encodeIfPresent(cid, forKey: .cid)
            try container.encode(authorDid, forKey: .authorDid)
            try container.encodeIfPresent(previewText, forKey: .previewText)
            try container.encodeIfPresent(createdAt, forKey: .createdAt)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
            if let value = cid {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(authorDid)
            if let value = previewText {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = createdAt {
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
            if authorDid != other.authorDid {
                return false
            }
            if previewText != other.previewText {
                return false
            }
            if createdAt != other.createdAt {
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
            if let value = cid {
                let cidValue = try value.toCBORValue()
                map = map.adding(key: "cid", value: cidValue)
            }
            let authorDidValue = try authorDid.toCBORValue()
            map = map.adding(key: "authorDid", value: authorDidValue)
            if let value = previewText {
                let previewTextValue = try value.toCBORValue()
                map = map.adding(key: "previewText", value: previewTextValue)
            }
            if let value = createdAt {
                let createdAtValue = try value.toCBORValue()
                map = map.adding(key: "createdAt", value: createdAtValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
            case cid
            case authorDid
            case previewText
            case createdAt
        }
    }

    public struct LinkEmbed: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "blue.catbird.mls.message.defs#linkEmbed"
        public let url: URI
        public let title: String?
        public let description: String?
        public let thumbnailURL: URI?
        public let domain: String?

        public init(
            url: URI, title: String?, description: String?, thumbnailURL: URI?, domain: String?
        ) {
            self.url = url
            self.title = title
            self.description = description
            self.thumbnailURL = thumbnailURL
            self.domain = domain
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                url = try container.decode(URI.self, forKey: .url)
            } catch {
                LogManager.logError("Decoding error for required property 'url': \(error)")
                throw error
            }
            do {
                title = try container.decodeIfPresent(String.self, forKey: .title)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'title': \(error)")
                throw error
            }
            do {
                description = try container.decodeIfPresent(String.self, forKey: .description)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'description': \(error)")
                throw error
            }
            do {
                thumbnailURL = try container.decodeIfPresent(URI.self, forKey: .thumbnailURL)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'thumbnailURL': \(error)")
                throw error
            }
            do {
                domain = try container.decodeIfPresent(String.self, forKey: .domain)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'domain': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(url, forKey: .url)
            try container.encodeIfPresent(title, forKey: .title)
            try container.encodeIfPresent(description, forKey: .description)
            try container.encodeIfPresent(thumbnailURL, forKey: .thumbnailURL)
            try container.encodeIfPresent(domain, forKey: .domain)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(url)
            if let value = title {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = description {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = thumbnailURL {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = domain {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if url != other.url {
                return false
            }
            if title != other.title {
                return false
            }
            if description != other.description {
                return false
            }
            if thumbnailURL != other.thumbnailURL {
                return false
            }
            if domain != other.domain {
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
            let urlValue = try url.toCBORValue()
            map = map.adding(key: "url", value: urlValue)
            if let value = title {
                let titleValue = try value.toCBORValue()
                map = map.adding(key: "title", value: titleValue)
            }
            if let value = description {
                let descriptionValue = try value.toCBORValue()
                map = map.adding(key: "description", value: descriptionValue)
            }
            if let value = thumbnailURL {
                let thumbnailURLValue = try value.toCBORValue()
                map = map.adding(key: "thumbnailURL", value: thumbnailURLValue)
            }
            if let value = domain {
                let domainValue = try value.toCBORValue()
                map = map.adding(key: "domain", value: domainValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case url
            case title
            case description
            case thumbnailURL
            case domain
        }
    }

    public struct GifEmbed: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "blue.catbird.mls.message.defs#gifEmbed"
        public let tenorURL: URI
        public let mp4URL: URI
        public let title: String?
        public let thumbnailURL: URI?
        public let width: Int?
        public let height: Int?

        public init(
            tenorURL: URI, mp4URL: URI, title: String?, thumbnailURL: URI?, width: Int?, height: Int?
        ) {
            self.tenorURL = tenorURL
            self.mp4URL = mp4URL
            self.title = title
            self.thumbnailURL = thumbnailURL
            self.width = width
            self.height = height
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                tenorURL = try container.decode(URI.self, forKey: .tenorURL)
            } catch {
                LogManager.logError("Decoding error for required property 'tenorURL': \(error)")
                throw error
            }
            do {
                mp4URL = try container.decode(URI.self, forKey: .mp4URL)
            } catch {
                LogManager.logError("Decoding error for required property 'mp4URL': \(error)")
                throw error
            }
            do {
                title = try container.decodeIfPresent(String.self, forKey: .title)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'title': \(error)")
                throw error
            }
            do {
                thumbnailURL = try container.decodeIfPresent(URI.self, forKey: .thumbnailURL)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'thumbnailURL': \(error)")
                throw error
            }
            do {
                width = try container.decodeIfPresent(Int.self, forKey: .width)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'width': \(error)")
                throw error
            }
            do {
                height = try container.decodeIfPresent(Int.self, forKey: .height)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'height': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(tenorURL, forKey: .tenorURL)
            try container.encode(mp4URL, forKey: .mp4URL)
            try container.encodeIfPresent(title, forKey: .title)
            try container.encodeIfPresent(thumbnailURL, forKey: .thumbnailURL)
            try container.encodeIfPresent(width, forKey: .width)
            try container.encodeIfPresent(height, forKey: .height)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(tenorURL)
            hasher.combine(mp4URL)
            if let value = title {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = thumbnailURL {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = width {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = height {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if tenorURL != other.tenorURL {
                return false
            }
            if mp4URL != other.mp4URL {
                return false
            }
            if title != other.title {
                return false
            }
            if thumbnailURL != other.thumbnailURL {
                return false
            }
            if width != other.width {
                return false
            }
            if height != other.height {
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
            let tenorURLValue = try tenorURL.toCBORValue()
            map = map.adding(key: "tenorURL", value: tenorURLValue)
            let mp4URLValue = try mp4URL.toCBORValue()
            map = map.adding(key: "mp4URL", value: mp4URLValue)
            if let value = title {
                let titleValue = try value.toCBORValue()
                map = map.adding(key: "title", value: titleValue)
            }
            if let value = thumbnailURL {
                let thumbnailURLValue = try value.toCBORValue()
                map = map.adding(key: "thumbnailURL", value: thumbnailURLValue)
            }
            if let value = width {
                let widthValue = try value.toCBORValue()
                map = map.adding(key: "width", value: widthValue)
            }
            if let value = height {
                let heightValue = try value.toCBORValue()
                map = map.adding(key: "height", value: heightValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case tenorURL
            case mp4URL
            case title
            case thumbnailURL
            case width
            case height
        }
    }

    public struct AdminRoster: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "blue.catbird.mls.message.defs#adminRoster"
        public let version: Int
        public let admins: [DID]
        public let hash: String?

        public init(
            version: Int, admins: [DID], hash: String?
        ) {
            self.version = version
            self.admins = admins
            self.hash = hash
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                version = try container.decode(Int.self, forKey: .version)
            } catch {
                LogManager.logError("Decoding error for required property 'version': \(error)")
                throw error
            }
            do {
                admins = try container.decode([DID].self, forKey: .admins)
            } catch {
                LogManager.logError("Decoding error for required property 'admins': \(error)")
                throw error
            }
            do {
                hash = try container.decodeIfPresent(String.self, forKey: .hash)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'hash': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(version, forKey: .version)
            try container.encode(admins, forKey: .admins)
            try container.encodeIfPresent(hash, forKey: .hash)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(version)
            hasher.combine(admins)
            if let value = hash {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if version != other.version {
                return false
            }
            if admins != other.admins {
                return false
            }
            if hash != other.hash {
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
            let versionValue = try version.toCBORValue()
            map = map.adding(key: "version", value: versionValue)
            let adminsValue = try admins.toCBORValue()
            map = map.adding(key: "admins", value: adminsValue)
            if let value = hash {
                let hashValue = try value.toCBORValue()
                map = map.adding(key: "hash", value: hashValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case version
            case admins
            case hash
        }
    }

    public struct AdminAction: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "blue.catbird.mls.message.defs#adminAction"
        public let action: String
        public let targetDid: DID
        public let timestamp: ATProtocolDate
        public let reason: String?

        public init(
            action: String, targetDid: DID, timestamp: ATProtocolDate, reason: String?
        ) {
            self.action = action
            self.targetDid = targetDid
            self.timestamp = timestamp
            self.reason = reason
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                action = try container.decode(String.self, forKey: .action)
            } catch {
                LogManager.logError("Decoding error for required property 'action': \(error)")
                throw error
            }
            do {
                targetDid = try container.decode(DID.self, forKey: .targetDid)
            } catch {
                LogManager.logError("Decoding error for required property 'targetDid': \(error)")
                throw error
            }
            do {
                timestamp = try container.decode(ATProtocolDate.self, forKey: .timestamp)
            } catch {
                LogManager.logError("Decoding error for required property 'timestamp': \(error)")
                throw error
            }
            do {
                reason = try container.decodeIfPresent(String.self, forKey: .reason)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'reason': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(action, forKey: .action)
            try container.encode(targetDid, forKey: .targetDid)
            try container.encode(timestamp, forKey: .timestamp)
            try container.encodeIfPresent(reason, forKey: .reason)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(action)
            hasher.combine(targetDid)
            hasher.combine(timestamp)
            if let value = reason {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if action != other.action {
                return false
            }
            if targetDid != other.targetDid {
                return false
            }
            if timestamp != other.timestamp {
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
            let actionValue = try action.toCBORValue()
            map = map.adding(key: "action", value: actionValue)
            let targetDidValue = try targetDid.toCBORValue()
            map = map.adding(key: "targetDid", value: targetDidValue)
            let timestampValue = try timestamp.toCBORValue()
            map = map.adding(key: "timestamp", value: timestampValue)
            if let value = reason {
                let reasonValue = try value.toCBORValue()
                map = map.adding(key: "reason", value: reasonValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case action
            case targetDid
            case timestamp
            case reason
        }
    }

    public struct ReactionPayload: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "blue.catbird.mls.message.defs#reactionPayload"
        public let messageId: String
        public let emoji: String
        public let action: String

        public init(
            messageId: String, emoji: String, action: String
        ) {
            self.messageId = messageId
            self.emoji = emoji
            self.action = action
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                messageId = try container.decode(String.self, forKey: .messageId)
            } catch {
                LogManager.logError("Decoding error for required property 'messageId': \(error)")
                throw error
            }
            do {
                emoji = try container.decode(String.self, forKey: .emoji)
            } catch {
                LogManager.logError("Decoding error for required property 'emoji': \(error)")
                throw error
            }
            do {
                action = try container.decode(String.self, forKey: .action)
            } catch {
                LogManager.logError("Decoding error for required property 'action': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(messageId, forKey: .messageId)
            try container.encode(emoji, forKey: .emoji)
            try container.encode(action, forKey: .action)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(messageId)
            hasher.combine(emoji)
            hasher.combine(action)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if messageId != other.messageId {
                return false
            }
            if emoji != other.emoji {
                return false
            }
            if action != other.action {
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
            let messageIdValue = try messageId.toCBORValue()
            map = map.adding(key: "messageId", value: messageIdValue)
            let emojiValue = try emoji.toCBORValue()
            map = map.adding(key: "emoji", value: emojiValue)
            let actionValue = try action.toCBORValue()
            map = map.adding(key: "action", value: actionValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case messageId
            case emoji
            case action
        }
    }

    public struct ReadReceiptPayload: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "blue.catbird.mls.message.defs#readReceiptPayload"
        public let messageId: String

        public init(
            messageId: String
        ) {
            self.messageId = messageId
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                messageId = try container.decode(String.self, forKey: .messageId)
            } catch {
                LogManager.logError("Decoding error for required property 'messageId': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(messageId, forKey: .messageId)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(messageId)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if messageId != other.messageId {
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
            let messageIdValue = try messageId.toCBORValue()
            map = map.adding(key: "messageId", value: messageIdValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case messageId
        }
    }

    public struct TypingPayload: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "blue.catbird.mls.message.defs#typingPayload"
        public let isTyping: Bool
        public let ts: Int?

        public init(
            isTyping: Bool, ts: Int?
        ) {
            self.isTyping = isTyping
            self.ts = ts
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                isTyping = try container.decode(Bool.self, forKey: .isTyping)
            } catch {
                LogManager.logError("Decoding error for required property 'isTyping': \(error)")
                throw error
            }
            do {
                ts = try container.decodeIfPresent(Int.self, forKey: .ts)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'ts': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(isTyping, forKey: .isTyping)
            try container.encodeIfPresent(ts, forKey: .ts)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(isTyping)
            if let value = ts {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if isTyping != other.isTyping {
                return false
            }
            if ts != other.ts {
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
            let isTypingValue = try isTyping.toCBORValue()
            map = map.adding(key: "isTyping", value: isTypingValue)
            if let value = ts {
                let tsValue = try value.toCBORValue()
                map = map.adding(key: "ts", value: tsValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case isTyping
            case ts
        }
    }

    public enum PayloadViewEmbedUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case blueCatbirdMlsMessageDefsRecordEmbed(BlueCatbirdMlsMessageDefs.RecordEmbed)
        case blueCatbirdMlsMessageDefsLinkEmbed(BlueCatbirdMlsMessageDefs.LinkEmbed)
        case blueCatbirdMlsMessageDefsGifEmbed(BlueCatbirdMlsMessageDefs.GifEmbed)
        case unexpected(ATProtocolValueContainer)
        public init(_ value: BlueCatbirdMlsMessageDefs.RecordEmbed) {
            self = .blueCatbirdMlsMessageDefsRecordEmbed(value)
        }

        public init(_ value: BlueCatbirdMlsMessageDefs.LinkEmbed) {
            self = .blueCatbirdMlsMessageDefsLinkEmbed(value)
        }

        public init(_ value: BlueCatbirdMlsMessageDefs.GifEmbed) {
            self = .blueCatbirdMlsMessageDefsGifEmbed(value)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            switch typeValue {
            case "blue.catbird.mls.message.defs#recordEmbed":
                let value = try BlueCatbirdMlsMessageDefs.RecordEmbed(from: decoder)
                self = .blueCatbirdMlsMessageDefsRecordEmbed(value)
            case "blue.catbird.mls.message.defs#linkEmbed":
                let value = try BlueCatbirdMlsMessageDefs.LinkEmbed(from: decoder)
                self = .blueCatbirdMlsMessageDefsLinkEmbed(value)
            case "blue.catbird.mls.message.defs#gifEmbed":
                let value = try BlueCatbirdMlsMessageDefs.GifEmbed(from: decoder)
                self = .blueCatbirdMlsMessageDefsGifEmbed(value)
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .blueCatbirdMlsMessageDefsRecordEmbed(value):
                try container.encode("blue.catbird.mls.message.defs#recordEmbed", forKey: .type)
                try value.encode(to: encoder)
            case let .blueCatbirdMlsMessageDefsLinkEmbed(value):
                try container.encode("blue.catbird.mls.message.defs#linkEmbed", forKey: .type)
                try value.encode(to: encoder)
            case let .blueCatbirdMlsMessageDefsGifEmbed(value):
                try container.encode("blue.catbird.mls.message.defs#gifEmbed", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .blueCatbirdMlsMessageDefsRecordEmbed(value):
                hasher.combine("blue.catbird.mls.message.defs#recordEmbed")
                hasher.combine(value)
            case let .blueCatbirdMlsMessageDefsLinkEmbed(value):
                hasher.combine("blue.catbird.mls.message.defs#linkEmbed")
                hasher.combine(value)
            case let .blueCatbirdMlsMessageDefsGifEmbed(value):
                hasher.combine("blue.catbird.mls.message.defs#gifEmbed")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: PayloadViewEmbedUnion, rhs: PayloadViewEmbedUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .blueCatbirdMlsMessageDefsRecordEmbed(lhsValue),
                .blueCatbirdMlsMessageDefsRecordEmbed(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .blueCatbirdMlsMessageDefsLinkEmbed(lhsValue),
                .blueCatbirdMlsMessageDefsLinkEmbed(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .blueCatbirdMlsMessageDefsGifEmbed(lhsValue),
                .blueCatbirdMlsMessageDefsGifEmbed(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? PayloadViewEmbedUnion else { return false }
            return self == other
        }

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .blueCatbirdMlsMessageDefsRecordEmbed(value):
                map = map.adding(key: "$type", value: "blue.catbird.mls.message.defs#recordEmbed")

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
            case let .blueCatbirdMlsMessageDefsLinkEmbed(value):
                map = map.adding(key: "$type", value: "blue.catbird.mls.message.defs#linkEmbed")

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
            case let .blueCatbirdMlsMessageDefsGifEmbed(value):
                map = map.adding(key: "$type", value: "blue.catbird.mls.message.defs#gifEmbed")

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
