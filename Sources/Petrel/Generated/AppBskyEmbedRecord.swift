import Foundation

// lexicon: 1, id: app.bsky.embed.record

public struct AppBskyEmbedRecord: ATProtocolCodable, ATProtocolValue {
    public static let typeIdentifier = "app.bsky.embed.record"
    public let record: ComAtprotoRepoStrongRef

    public init(record: ComAtprotoRepoStrongRef) {
        self.record = record
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        record = try container.decode(ComAtprotoRepoStrongRef.self, forKey: .record)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

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

    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        var map = OrderedCBORMap()

        let recordValue = try record.toCBORValue()
        map = map.adding(key: "record", value: recordValue)

        return map
    }

    private enum CodingKeys: String, CodingKey {
        case record
    }

    public struct View: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.embed.record#view"
        public let record: ViewRecordUnion

        // Standard initializer
        public init(
            record: ViewRecordUnion
        ) {
            self.record = record
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                record = try container.decode(ViewRecordUnion.self, forKey: .record)

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

        // DAGCBOR encoding with field ordering
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

    public struct ViewRecord: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.embed.record#viewRecord"
        public let uri: ATProtocolURI
        public let cid: CID
        public let author: AppBskyActorDefs.ProfileViewBasic
        public let value: ATProtocolValueContainer
        public let labels: [ComAtprotoLabelDefs.Label]?
        public let replyCount: Int?
        public let repostCount: Int?
        public let likeCount: Int?
        public let quoteCount: Int?
        public let embeds: [ViewRecordEmbedsUnion]?
        public let indexedAt: ATProtocolDate

        // Standard initializer
        public init(
            uri: ATProtocolURI, cid: CID, author: AppBskyActorDefs.ProfileViewBasic, value: ATProtocolValueContainer, labels: [ComAtprotoLabelDefs.Label]?, replyCount: Int?, repostCount: Int?, likeCount: Int?, quoteCount: Int?, embeds: [ViewRecordEmbedsUnion]?, indexedAt: ATProtocolDate
        ) {
            self.uri = uri
            self.cid = cid
            self.author = author
            self.value = value
            self.labels = labels
            self.replyCount = replyCount
            self.repostCount = repostCount
            self.likeCount = likeCount
            self.quoteCount = quoteCount
            self.embeds = embeds
            self.indexedAt = indexedAt
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                uri = try container.decode(ATProtocolURI.self, forKey: .uri)

            } catch {
                LogManager.logError("Decoding error for required property 'uri': \(error)")

                throw error
            }
            do {
                cid = try container.decode(CID.self, forKey: .cid)

            } catch {
                LogManager.logError("Decoding error for required property 'cid': \(error)")

                throw error
            }
            do {
                author = try container.decode(AppBskyActorDefs.ProfileViewBasic.self, forKey: .author)

            } catch {
                LogManager.logError("Decoding error for required property 'author': \(error)")

                throw error
            }
            do {
                value = try container.decode(ATProtocolValueContainer.self, forKey: .value)

            } catch {
                LogManager.logError("Decoding error for required property 'value': \(error)")

                throw error
            }
            do {
                labels = try container.decodeIfPresent([ComAtprotoLabelDefs.Label].self, forKey: .labels)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'labels': \(error)")

                throw error
            }
            do {
                replyCount = try container.decodeIfPresent(Int.self, forKey: .replyCount)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'replyCount': \(error)")

                throw error
            }
            do {
                repostCount = try container.decodeIfPresent(Int.self, forKey: .repostCount)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'repostCount': \(error)")

                throw error
            }
            do {
                likeCount = try container.decodeIfPresent(Int.self, forKey: .likeCount)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'likeCount': \(error)")

                throw error
            }
            do {
                quoteCount = try container.decodeIfPresent(Int.self, forKey: .quoteCount)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'quoteCount': \(error)")

                throw error
            }
            do {
                embeds = try container.decodeIfPresent([ViewRecordEmbedsUnion].self, forKey: .embeds)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'embeds': \(error)")

                throw error
            }
            do {
                indexedAt = try container.decode(ATProtocolDate.self, forKey: .indexedAt)

            } catch {
                LogManager.logError("Decoding error for required property 'indexedAt': \(error)")

                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(uri, forKey: .uri)

            try container.encode(cid, forKey: .cid)

            try container.encode(author, forKey: .author)

            try container.encode(value, forKey: .value)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(labels, forKey: .labels)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(replyCount, forKey: .replyCount)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(repostCount, forKey: .repostCount)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(likeCount, forKey: .likeCount)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(quoteCount, forKey: .quoteCount)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(embeds, forKey: .embeds)

            try container.encode(indexedAt, forKey: .indexedAt)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
            hasher.combine(cid)
            hasher.combine(author)
            hasher.combine(value)
            if let value = labels {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = replyCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = repostCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = likeCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = quoteCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = embeds {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(indexedAt)
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

            if value != other.value {
                return false
            }

            if labels != other.labels {
                return false
            }

            if replyCount != other.replyCount {
                return false
            }

            if repostCount != other.repostCount {
                return false
            }

            if likeCount != other.likeCount {
                return false
            }

            if quoteCount != other.quoteCount {
                return false
            }

            if embeds != other.embeds {
                return false
            }

            if indexedAt != other.indexedAt {
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

            let uriValue = try uri.toCBORValue()
            map = map.adding(key: "uri", value: uriValue)

            let cidValue = try cid.toCBORValue()
            map = map.adding(key: "cid", value: cidValue)

            let authorValue = try author.toCBORValue()
            map = map.adding(key: "author", value: authorValue)

            let valueValue = try value.toCBORValue()
            map = map.adding(key: "value", value: valueValue)

            if let value = labels {
                // Encode optional property even if it's an empty array for CBOR

                let labelsValue = try value.toCBORValue()
                map = map.adding(key: "labels", value: labelsValue)
            }

            if let value = replyCount {
                // Encode optional property even if it's an empty array for CBOR

                let replyCountValue = try value.toCBORValue()
                map = map.adding(key: "replyCount", value: replyCountValue)
            }

            if let value = repostCount {
                // Encode optional property even if it's an empty array for CBOR

                let repostCountValue = try value.toCBORValue()
                map = map.adding(key: "repostCount", value: repostCountValue)
            }

            if let value = likeCount {
                // Encode optional property even if it's an empty array for CBOR

                let likeCountValue = try value.toCBORValue()
                map = map.adding(key: "likeCount", value: likeCountValue)
            }

            if let value = quoteCount {
                // Encode optional property even if it's an empty array for CBOR

                let quoteCountValue = try value.toCBORValue()
                map = map.adding(key: "quoteCount", value: quoteCountValue)
            }

            if let value = embeds {
                // Encode optional property even if it's an empty array for CBOR

                let embedsValue = try value.toCBORValue()
                map = map.adding(key: "embeds", value: embedsValue)
            }

            let indexedAtValue = try indexedAt.toCBORValue()
            map = map.adding(key: "indexedAt", value: indexedAtValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
            case cid
            case author
            case value
            case labels
            case replyCount
            case repostCount
            case likeCount
            case quoteCount
            case embeds
            case indexedAt
        }
    }

    public struct ViewNotFound: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.embed.record#viewNotFound"
        public let uri: ATProtocolURI
        public let notFound: Bool

        // Standard initializer
        public init(
            uri: ATProtocolURI, notFound: Bool
        ) {
            self.uri = uri
            self.notFound = notFound
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                uri = try container.decode(ATProtocolURI.self, forKey: .uri)

            } catch {
                LogManager.logError("Decoding error for required property 'uri': \(error)")

                throw error
            }
            do {
                notFound = try container.decode(Bool.self, forKey: .notFound)

            } catch {
                LogManager.logError("Decoding error for required property 'notFound': \(error)")

                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(uri, forKey: .uri)

            try container.encode(notFound, forKey: .notFound)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
            hasher.combine(notFound)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if uri != other.uri {
                return false
            }

            if notFound != other.notFound {
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

            let uriValue = try uri.toCBORValue()
            map = map.adding(key: "uri", value: uriValue)

            let notFoundValue = try notFound.toCBORValue()
            map = map.adding(key: "notFound", value: notFoundValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
            case notFound
        }
    }

    public struct ViewBlocked: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.embed.record#viewBlocked"
        public let uri: ATProtocolURI
        public let blocked: Bool
        public let author: AppBskyFeedDefs.BlockedAuthor

        // Standard initializer
        public init(
            uri: ATProtocolURI, blocked: Bool, author: AppBskyFeedDefs.BlockedAuthor
        ) {
            self.uri = uri
            self.blocked = blocked
            self.author = author
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                uri = try container.decode(ATProtocolURI.self, forKey: .uri)

            } catch {
                LogManager.logError("Decoding error for required property 'uri': \(error)")

                throw error
            }
            do {
                blocked = try container.decode(Bool.self, forKey: .blocked)

            } catch {
                LogManager.logError("Decoding error for required property 'blocked': \(error)")

                throw error
            }
            do {
                author = try container.decode(AppBskyFeedDefs.BlockedAuthor.self, forKey: .author)

            } catch {
                LogManager.logError("Decoding error for required property 'author': \(error)")

                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(uri, forKey: .uri)

            try container.encode(blocked, forKey: .blocked)

            try container.encode(author, forKey: .author)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
            hasher.combine(blocked)
            hasher.combine(author)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if uri != other.uri {
                return false
            }

            if blocked != other.blocked {
                return false
            }

            if author != other.author {
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

            let uriValue = try uri.toCBORValue()
            map = map.adding(key: "uri", value: uriValue)

            let blockedValue = try blocked.toCBORValue()
            map = map.adding(key: "blocked", value: blockedValue)

            let authorValue = try author.toCBORValue()
            map = map.adding(key: "author", value: authorValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
            case blocked
            case author
        }
    }

    public struct ViewDetached: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.embed.record#viewDetached"
        public let uri: ATProtocolURI
        public let detached: Bool

        // Standard initializer
        public init(
            uri: ATProtocolURI, detached: Bool
        ) {
            self.uri = uri
            self.detached = detached
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                uri = try container.decode(ATProtocolURI.self, forKey: .uri)

            } catch {
                LogManager.logError("Decoding error for required property 'uri': \(error)")

                throw error
            }
            do {
                detached = try container.decode(Bool.self, forKey: .detached)

            } catch {
                LogManager.logError("Decoding error for required property 'detached': \(error)")

                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(uri, forKey: .uri)

            try container.encode(detached, forKey: .detached)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
            hasher.combine(detached)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if uri != other.uri {
                return false
            }

            if detached != other.detached {
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

            let uriValue = try uri.toCBORValue()
            map = map.adding(key: "uri", value: uriValue)

            let detachedValue = try detached.toCBORValue()
            map = map.adding(key: "detached", value: detachedValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
            case detached
        }
    }

    public enum ViewRecordUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case appBskyEmbedRecordViewRecord(AppBskyEmbedRecord.ViewRecord)
        case appBskyEmbedRecordViewNotFound(AppBskyEmbedRecord.ViewNotFound)
        case appBskyEmbedRecordViewBlocked(AppBskyEmbedRecord.ViewBlocked)
        case appBskyEmbedRecordViewDetached(AppBskyEmbedRecord.ViewDetached)
        case appBskyFeedDefsGeneratorView(AppBskyFeedDefs.GeneratorView)
        case appBskyGraphDefsListView(AppBskyGraphDefs.ListView)
        case appBskyLabelerDefsLabelerView(AppBskyLabelerDefs.LabelerView)
        case appBskyGraphDefsStarterPackViewBasic(AppBskyGraphDefs.StarterPackViewBasic)
        case unexpected(ATProtocolValueContainer)

        public init(_ value: AppBskyEmbedRecord.ViewRecord) {
            self = .appBskyEmbedRecordViewRecord(value)
        }

        public init(_ value: AppBskyEmbedRecord.ViewNotFound) {
            self = .appBskyEmbedRecordViewNotFound(value)
        }

        public init(_ value: AppBskyEmbedRecord.ViewBlocked) {
            self = .appBskyEmbedRecordViewBlocked(value)
        }

        public init(_ value: AppBskyEmbedRecord.ViewDetached) {
            self = .appBskyEmbedRecordViewDetached(value)
        }

        public init(_ value: AppBskyFeedDefs.GeneratorView) {
            self = .appBskyFeedDefsGeneratorView(value)
        }

        public init(_ value: AppBskyGraphDefs.ListView) {
            self = .appBskyGraphDefsListView(value)
        }

        public init(_ value: AppBskyLabelerDefs.LabelerView) {
            self = .appBskyLabelerDefsLabelerView(value)
        }

        public init(_ value: AppBskyGraphDefs.StarterPackViewBasic) {
            self = .appBskyGraphDefsStarterPackViewBasic(value)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            switch typeValue {
            case "app.bsky.embed.record#viewRecord":
                let value = try AppBskyEmbedRecord.ViewRecord(from: decoder)
                self = .appBskyEmbedRecordViewRecord(value)
            case "app.bsky.embed.record#viewNotFound":
                let value = try AppBskyEmbedRecord.ViewNotFound(from: decoder)
                self = .appBskyEmbedRecordViewNotFound(value)
            case "app.bsky.embed.record#viewBlocked":
                let value = try AppBskyEmbedRecord.ViewBlocked(from: decoder)
                self = .appBskyEmbedRecordViewBlocked(value)
            case "app.bsky.embed.record#viewDetached":
                let value = try AppBskyEmbedRecord.ViewDetached(from: decoder)
                self = .appBskyEmbedRecordViewDetached(value)
            case "app.bsky.feed.defs#generatorView":
                let value = try AppBskyFeedDefs.GeneratorView(from: decoder)
                self = .appBskyFeedDefsGeneratorView(value)
            case "app.bsky.graph.defs#listView":
                let value = try AppBskyGraphDefs.ListView(from: decoder)
                self = .appBskyGraphDefsListView(value)
            case "app.bsky.labeler.defs#labelerView":
                let value = try AppBskyLabelerDefs.LabelerView(from: decoder)
                self = .appBskyLabelerDefsLabelerView(value)
            case "app.bsky.graph.defs#starterPackViewBasic":
                let value = try AppBskyGraphDefs.StarterPackViewBasic(from: decoder)
                self = .appBskyGraphDefsStarterPackViewBasic(value)
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .appBskyEmbedRecordViewRecord(value):
                try container.encode("app.bsky.embed.record#viewRecord", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyEmbedRecordViewNotFound(value):
                try container.encode("app.bsky.embed.record#viewNotFound", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyEmbedRecordViewBlocked(value):
                try container.encode("app.bsky.embed.record#viewBlocked", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyEmbedRecordViewDetached(value):
                try container.encode("app.bsky.embed.record#viewDetached", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyFeedDefsGeneratorView(value):
                try container.encode("app.bsky.feed.defs#generatorView", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyGraphDefsListView(value):
                try container.encode("app.bsky.graph.defs#listView", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyLabelerDefsLabelerView(value):
                try container.encode("app.bsky.labeler.defs#labelerView", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyGraphDefsStarterPackViewBasic(value):
                try container.encode("app.bsky.graph.defs#starterPackViewBasic", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .appBskyEmbedRecordViewRecord(value):
                hasher.combine("app.bsky.embed.record#viewRecord")
                hasher.combine(value)
            case let .appBskyEmbedRecordViewNotFound(value):
                hasher.combine("app.bsky.embed.record#viewNotFound")
                hasher.combine(value)
            case let .appBskyEmbedRecordViewBlocked(value):
                hasher.combine("app.bsky.embed.record#viewBlocked")
                hasher.combine(value)
            case let .appBskyEmbedRecordViewDetached(value):
                hasher.combine("app.bsky.embed.record#viewDetached")
                hasher.combine(value)
            case let .appBskyFeedDefsGeneratorView(value):
                hasher.combine("app.bsky.feed.defs#generatorView")
                hasher.combine(value)
            case let .appBskyGraphDefsListView(value):
                hasher.combine("app.bsky.graph.defs#listView")
                hasher.combine(value)
            case let .appBskyLabelerDefsLabelerView(value):
                hasher.combine("app.bsky.labeler.defs#labelerView")
                hasher.combine(value)
            case let .appBskyGraphDefsStarterPackViewBasic(value):
                hasher.combine("app.bsky.graph.defs#starterPackViewBasic")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: ViewRecordUnion, rhs: ViewRecordUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .appBskyEmbedRecordViewRecord(lhsValue),
                .appBskyEmbedRecordViewRecord(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyEmbedRecordViewNotFound(lhsValue),
                .appBskyEmbedRecordViewNotFound(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyEmbedRecordViewBlocked(lhsValue),
                .appBskyEmbedRecordViewBlocked(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyEmbedRecordViewDetached(lhsValue),
                .appBskyEmbedRecordViewDetached(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyFeedDefsGeneratorView(lhsValue),
                .appBskyFeedDefsGeneratorView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyGraphDefsListView(lhsValue),
                .appBskyGraphDefsListView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyLabelerDefsLabelerView(lhsValue),
                .appBskyLabelerDefsLabelerView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyGraphDefsStarterPackViewBasic(lhsValue),
                .appBskyGraphDefsStarterPackViewBasic(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? ViewRecordUnion else { return false }
            return self == other
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .appBskyEmbedRecordViewRecord(value):
                map = map.adding(key: "$type", value: "app.bsky.embed.record#viewRecord")

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
            case let .appBskyEmbedRecordViewNotFound(value):
                map = map.adding(key: "$type", value: "app.bsky.embed.record#viewNotFound")

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
            case let .appBskyEmbedRecordViewBlocked(value):
                map = map.adding(key: "$type", value: "app.bsky.embed.record#viewBlocked")

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
            case let .appBskyEmbedRecordViewDetached(value):
                map = map.adding(key: "$type", value: "app.bsky.embed.record#viewDetached")

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
            case let .appBskyFeedDefsGeneratorView(value):
                map = map.adding(key: "$type", value: "app.bsky.feed.defs#generatorView")

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
            case let .appBskyGraphDefsListView(value):
                map = map.adding(key: "$type", value: "app.bsky.graph.defs#listView")

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
            case let .appBskyLabelerDefsLabelerView(value):
                map = map.adding(key: "$type", value: "app.bsky.labeler.defs#labelerView")

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
            case let .appBskyGraphDefsStarterPackViewBasic(value):
                map = map.adding(key: "$type", value: "app.bsky.graph.defs#starterPackViewBasic")

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

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .appBskyEmbedRecordViewRecord(value):
                return value.hasPendingData
            case let .appBskyEmbedRecordViewNotFound(value):
                return value.hasPendingData
            case let .appBskyEmbedRecordViewBlocked(value):
                return value.hasPendingData
            case let .appBskyEmbedRecordViewDetached(value):
                return value.hasPendingData
            case let .appBskyFeedDefsGeneratorView(value):
                return value.hasPendingData
            case let .appBskyGraphDefsListView(value):
                return value.hasPendingData
            case let .appBskyLabelerDefsLabelerView(value):
                return value.hasPendingData
            case let .appBskyGraphDefsStarterPackViewBasic(value):
                return value.hasPendingData
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .appBskyEmbedRecordViewRecord(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .appBskyEmbedRecordViewRecord(value)
            case var .appBskyEmbedRecordViewNotFound(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .appBskyEmbedRecordViewNotFound(value)
            case var .appBskyEmbedRecordViewBlocked(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .appBskyEmbedRecordViewBlocked(value)
            case var .appBskyEmbedRecordViewDetached(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .appBskyEmbedRecordViewDetached(value)
            case var .appBskyFeedDefsGeneratorView(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .appBskyFeedDefsGeneratorView(value)
            case var .appBskyGraphDefsListView(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .appBskyGraphDefsListView(value)
            case var .appBskyLabelerDefsLabelerView(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .appBskyLabelerDefsLabelerView(value)
            case var .appBskyGraphDefsStarterPackViewBasic(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .appBskyGraphDefsStarterPackViewBasic(value)
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }

    public enum ViewRecordEmbedsUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case appBskyEmbedImagesView(AppBskyEmbedImages.View)
        case appBskyEmbedVideoView(AppBskyEmbedVideo.View)
        case appBskyEmbedExternalView(AppBskyEmbedExternal.View)
        case appBskyEmbedRecordView(AppBskyEmbedRecord.View)
        case appBskyEmbedRecordWithMediaView(AppBskyEmbedRecordWithMedia.View)
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

        public init(_ value: AppBskyEmbedRecord.View) {
            self = .appBskyEmbedRecordView(value)
        }

        public init(_ value: AppBskyEmbedRecordWithMedia.View) {
            self = .appBskyEmbedRecordWithMediaView(value)
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
            case "app.bsky.embed.record#view":
                let value = try AppBskyEmbedRecord.View(from: decoder)
                self = .appBskyEmbedRecordView(value)
            case "app.bsky.embed.recordWithMedia#view":
                let value = try AppBskyEmbedRecordWithMedia.View(from: decoder)
                self = .appBskyEmbedRecordWithMediaView(value)
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
            case let .appBskyEmbedRecordView(value):
                try container.encode("app.bsky.embed.record#view", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyEmbedRecordWithMediaView(value):
                try container.encode("app.bsky.embed.recordWithMedia#view", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
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
            case let .appBskyEmbedRecordView(value):
                hasher.combine("app.bsky.embed.record#view")
                hasher.combine(value)
            case let .appBskyEmbedRecordWithMediaView(value):
                hasher.combine("app.bsky.embed.recordWithMedia#view")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: ViewRecordEmbedsUnion, rhs: ViewRecordEmbedsUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .appBskyEmbedImagesView(lhsValue),
                .appBskyEmbedImagesView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyEmbedVideoView(lhsValue),
                .appBskyEmbedVideoView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyEmbedExternalView(lhsValue),
                .appBskyEmbedExternalView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyEmbedRecordView(lhsValue),
                .appBskyEmbedRecordView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyEmbedRecordWithMediaView(lhsValue),
                .appBskyEmbedRecordWithMediaView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? ViewRecordEmbedsUnion else { return false }
            return self == other
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .appBskyEmbedImagesView(value):
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
            case let .appBskyEmbedVideoView(value):
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
            case let .appBskyEmbedExternalView(value):
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
            case let .appBskyEmbedRecordView(value):
                map = map.adding(key: "$type", value: "app.bsky.embed.record#view")

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
            case let .appBskyEmbedRecordWithMediaView(value):
                map = map.adding(key: "$type", value: "app.bsky.embed.recordWithMedia#view")

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

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .appBskyEmbedImagesView(value):
                return value.hasPendingData
            case let .appBskyEmbedVideoView(value):
                return value.hasPendingData
            case let .appBskyEmbedExternalView(value):
                return value.hasPendingData
            case let .appBskyEmbedRecordView(value):
                return value.hasPendingData
            case let .appBskyEmbedRecordWithMediaView(value):
                return value.hasPendingData
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .appBskyEmbedImagesView(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .appBskyEmbedImagesView(value)
            case var .appBskyEmbedVideoView(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .appBskyEmbedVideoView(value)
            case var .appBskyEmbedExternalView(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .appBskyEmbedExternalView(value)
            case var .appBskyEmbedRecordView(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .appBskyEmbedRecordView(value)
            case var .appBskyEmbedRecordWithMediaView(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .appBskyEmbedRecordWithMediaView(value)
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }
}
