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
                LogManager.logError("Decoding error for property 'record': \(error)")
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

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case record
        }
    }

    public struct ViewRecord: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.embed.record#viewRecord"
        public let uri: ATProtocolURI
        public let cid: String
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
            uri: ATProtocolURI, cid: String, author: AppBskyActorDefs.ProfileViewBasic, value: ATProtocolValueContainer, labels: [ComAtprotoLabelDefs.Label]?, replyCount: Int?, repostCount: Int?, likeCount: Int?, quoteCount: Int?, embeds: [ViewRecordEmbedsUnion]?, indexedAt: ATProtocolDate
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
                LogManager.logError("Decoding error for property 'uri': \(error)")
                throw error
            }
            do {
                cid = try container.decode(String.self, forKey: .cid)

            } catch {
                LogManager.logError("Decoding error for property 'cid': \(error)")
                throw error
            }
            do {
                author = try container.decode(AppBskyActorDefs.ProfileViewBasic.self, forKey: .author)

            } catch {
                LogManager.logError("Decoding error for property 'author': \(error)")
                throw error
            }
            do {
                value = try container.decode(ATProtocolValueContainer.self, forKey: .value)

            } catch {
                LogManager.logError("Decoding error for property 'value': \(error)")
                throw error
            }
            do {
                labels = try container.decodeIfPresent([ComAtprotoLabelDefs.Label].self, forKey: .labels)

            } catch {
                LogManager.logError("Decoding error for property 'labels': \(error)")
                throw error
            }
            do {
                replyCount = try container.decodeIfPresent(Int.self, forKey: .replyCount)

            } catch {
                LogManager.logError("Decoding error for property 'replyCount': \(error)")
                throw error
            }
            do {
                repostCount = try container.decodeIfPresent(Int.self, forKey: .repostCount)

            } catch {
                LogManager.logError("Decoding error for property 'repostCount': \(error)")
                throw error
            }
            do {
                likeCount = try container.decodeIfPresent(Int.self, forKey: .likeCount)

            } catch {
                LogManager.logError("Decoding error for property 'likeCount': \(error)")
                throw error
            }
            do {
                quoteCount = try container.decodeIfPresent(Int.self, forKey: .quoteCount)

            } catch {
                LogManager.logError("Decoding error for property 'quoteCount': \(error)")
                throw error
            }
            do {
                embeds = try container.decodeIfPresent([ViewRecordEmbedsUnion].self, forKey: .embeds)

            } catch {
                LogManager.logError("Decoding error for property 'embeds': \(error)")
                throw error
            }
            do {
                indexedAt = try container.decode(ATProtocolDate.self, forKey: .indexedAt)

            } catch {
                LogManager.logError("Decoding error for property 'indexedAt': \(error)")
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

            if let value = labels {
                try container.encode(value, forKey: .labels)
            }

            if let value = replyCount {
                try container.encode(value, forKey: .replyCount)
            }

            if let value = repostCount {
                try container.encode(value, forKey: .repostCount)
            }

            if let value = likeCount {
                try container.encode(value, forKey: .likeCount)
            }

            if let value = quoteCount {
                try container.encode(value, forKey: .quoteCount)
            }

            if let value = embeds {
                try container.encode(value, forKey: .embeds)
            }

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
                LogManager.logError("Decoding error for property 'uri': \(error)")
                throw error
            }
            do {
                notFound = try container.decode(Bool.self, forKey: .notFound)

            } catch {
                LogManager.logError("Decoding error for property 'notFound': \(error)")
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
                LogManager.logError("Decoding error for property 'uri': \(error)")
                throw error
            }
            do {
                blocked = try container.decode(Bool.self, forKey: .blocked)

            } catch {
                LogManager.logError("Decoding error for property 'blocked': \(error)")
                throw error
            }
            do {
                author = try container.decode(AppBskyFeedDefs.BlockedAuthor.self, forKey: .author)

            } catch {
                LogManager.logError("Decoding error for property 'author': \(error)")
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
                LogManager.logError("Decoding error for property 'uri': \(error)")
                throw error
            }
            do {
                detached = try container.decode(Bool.self, forKey: .detached)

            } catch {
                LogManager.logError("Decoding error for property 'detached': \(error)")
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

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
            case detached
        }
    }

    public enum ViewRecordUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, PendingDataLoadable, Equatable {
        case appBskyEmbedRecordViewRecord(AppBskyEmbedRecord.ViewRecord)
        case appBskyEmbedRecordViewNotFound(AppBskyEmbedRecord.ViewNotFound)
        case appBskyEmbedRecordViewBlocked(AppBskyEmbedRecord.ViewBlocked)
        case appBskyEmbedRecordViewDetached(AppBskyEmbedRecord.ViewDetached)
        case appBskyFeedDefsGeneratorView(AppBskyFeedDefs.GeneratorView)
        case appBskyGraphDefsListView(AppBskyGraphDefs.ListView)
        case appBskyLabelerDefsLabelerView(AppBskyLabelerDefs.LabelerView)
        case appBskyGraphDefsStarterPackViewBasic(AppBskyGraphDefs.StarterPackViewBasic)
        case unexpected(ATProtocolValueContainer)

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
            case rawContent = "_rawContent"
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
            guard let otherValue = other as? ViewRecordUnion else { return false }
            return self == otherValue
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .appBskyEmbedRecordViewRecord(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .appBskyEmbedRecordViewNotFound(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .appBskyEmbedRecordViewBlocked(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .appBskyEmbedRecordViewDetached(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .appBskyFeedDefsGeneratorView(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .appBskyGraphDefsListView(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .appBskyLabelerDefsLabelerView(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .appBskyGraphDefsStarterPackViewBasic(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .appBskyEmbedRecordViewRecord(value):
                if var loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    await loadable.loadPendingData()
                    // Update value after loading pending data
                    if let updatedValue = loadable as? AppBskyEmbedRecord.ViewRecord {
                        self = .appBskyEmbedRecordViewRecord(updatedValue)
                    }
                }
            case var .appBskyEmbedRecordViewNotFound(value):
                if var loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    await loadable.loadPendingData()
                    // Update value after loading pending data
                    if let updatedValue = loadable as? AppBskyEmbedRecord.ViewNotFound {
                        self = .appBskyEmbedRecordViewNotFound(updatedValue)
                    }
                }
            case var .appBskyEmbedRecordViewBlocked(value):
                if var loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    await loadable.loadPendingData()
                    // Update value after loading pending data
                    if let updatedValue = loadable as? AppBskyEmbedRecord.ViewBlocked {
                        self = .appBskyEmbedRecordViewBlocked(updatedValue)
                    }
                }
            case var .appBskyEmbedRecordViewDetached(value):
                if var loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    await loadable.loadPendingData()
                    // Update value after loading pending data
                    if let updatedValue = loadable as? AppBskyEmbedRecord.ViewDetached {
                        self = .appBskyEmbedRecordViewDetached(updatedValue)
                    }
                }
            case var .appBskyFeedDefsGeneratorView(value):
                if var loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    await loadable.loadPendingData()
                    // Update value after loading pending data
                    if let updatedValue = loadable as? AppBskyFeedDefs.GeneratorView {
                        self = .appBskyFeedDefsGeneratorView(updatedValue)
                    }
                }
            case var .appBskyGraphDefsListView(value):
                if var loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    await loadable.loadPendingData()
                    // Update value after loading pending data
                    if let updatedValue = loadable as? AppBskyGraphDefs.ListView {
                        self = .appBskyGraphDefsListView(updatedValue)
                    }
                }
            case var .appBskyLabelerDefsLabelerView(value):
                if var loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    await loadable.loadPendingData()
                    // Update value after loading pending data
                    if let updatedValue = loadable as? AppBskyLabelerDefs.LabelerView {
                        self = .appBskyLabelerDefsLabelerView(updatedValue)
                    }
                }
            case var .appBskyGraphDefsStarterPackViewBasic(value):
                if var loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    await loadable.loadPendingData()
                    // Update value after loading pending data
                    if let updatedValue = loadable as? AppBskyGraphDefs.StarterPackViewBasic {
                        self = .appBskyGraphDefsStarterPackViewBasic(updatedValue)
                    }
                }
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }

    public enum ViewRecordEmbedsUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, PendingDataLoadable, Equatable {
        case appBskyEmbedImagesView(AppBskyEmbedImages.View)
        case appBskyEmbedVideoView(AppBskyEmbedVideo.View)
        case appBskyEmbedExternalView(AppBskyEmbedExternal.View)
        case appBskyEmbedRecordView(AppBskyEmbedRecord.View)
        case appBskyEmbedRecordWithMediaView(AppBskyEmbedRecordWithMedia.View)
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
            case rawContent = "_rawContent"
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
            guard let otherValue = other as? ViewRecordEmbedsUnion else { return false }
            return self == otherValue
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .appBskyEmbedImagesView(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .appBskyEmbedVideoView(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .appBskyEmbedExternalView(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .appBskyEmbedRecordView(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .appBskyEmbedRecordWithMediaView(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .appBskyEmbedImagesView(value):
                if var loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    await loadable.loadPendingData()
                    // Update value after loading pending data
                    if let updatedValue = loadable as? AppBskyEmbedImages.View {
                        self = .appBskyEmbedImagesView(updatedValue)
                    }
                }
            case var .appBskyEmbedVideoView(value):
                if var loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    await loadable.loadPendingData()
                    // Update value after loading pending data
                    if let updatedValue = loadable as? AppBskyEmbedVideo.View {
                        self = .appBskyEmbedVideoView(updatedValue)
                    }
                }
            case var .appBskyEmbedExternalView(value):
                if var loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    await loadable.loadPendingData()
                    // Update value after loading pending data
                    if let updatedValue = loadable as? AppBskyEmbedExternal.View {
                        self = .appBskyEmbedExternalView(updatedValue)
                    }
                }
            case var .appBskyEmbedRecordView(value):
                if var loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    await loadable.loadPendingData()
                    // Update value after loading pending data
                    if let updatedValue = loadable as? AppBskyEmbedRecord.View {
                        self = .appBskyEmbedRecordView(updatedValue)
                    }
                }
            case var .appBskyEmbedRecordWithMediaView(value):
                if var loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    await loadable.loadPendingData()
                    // Update value after loading pending data
                    if let updatedValue = loadable as? AppBskyEmbedRecordWithMedia.View {
                        self = .appBskyEmbedRecordWithMediaView(updatedValue)
                    }
                }
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }
}
