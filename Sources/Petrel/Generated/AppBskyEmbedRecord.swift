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
            
            self.record = try container.decode(ComAtprotoRepoStrongRef.self, forKey: .record)
            
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
            if self.record != other.record {
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
                
                self.record = try container.decode(ViewRecordUnion.self, forKey: .record)
                
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
            
            if self.record != other.record {
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
                
                self.uri = try container.decode(ATProtocolURI.self, forKey: .uri)
                
            } catch {
                LogManager.logError("Decoding error for property 'uri': \(error)")
                throw error
            }
            do {
                
                self.cid = try container.decode(String.self, forKey: .cid)
                
            } catch {
                LogManager.logError("Decoding error for property 'cid': \(error)")
                throw error
            }
            do {
                
                self.author = try container.decode(AppBskyActorDefs.ProfileViewBasic.self, forKey: .author)
                
            } catch {
                LogManager.logError("Decoding error for property 'author': \(error)")
                throw error
            }
            do {
                
                self.value = try container.decode(ATProtocolValueContainer.self, forKey: .value)
                
            } catch {
                LogManager.logError("Decoding error for property 'value': \(error)")
                throw error
            }
            do {
                
                self.labels = try container.decodeIfPresent([ComAtprotoLabelDefs.Label].self, forKey: .labels)
                
            } catch {
                LogManager.logError("Decoding error for property 'labels': \(error)")
                throw error
            }
            do {
                
                self.replyCount = try container.decodeIfPresent(Int.self, forKey: .replyCount)
                
            } catch {
                LogManager.logError("Decoding error for property 'replyCount': \(error)")
                throw error
            }
            do {
                
                self.repostCount = try container.decodeIfPresent(Int.self, forKey: .repostCount)
                
            } catch {
                LogManager.logError("Decoding error for property 'repostCount': \(error)")
                throw error
            }
            do {
                
                self.likeCount = try container.decodeIfPresent(Int.self, forKey: .likeCount)
                
            } catch {
                LogManager.logError("Decoding error for property 'likeCount': \(error)")
                throw error
            }
            do {
                
                self.quoteCount = try container.decodeIfPresent(Int.self, forKey: .quoteCount)
                
            } catch {
                LogManager.logError("Decoding error for property 'quoteCount': \(error)")
                throw error
            }
            do {
                
                self.embeds = try container.decodeIfPresent([ViewRecordEmbedsUnion].self, forKey: .embeds)
                
            } catch {
                LogManager.logError("Decoding error for property 'embeds': \(error)")
                throw error
            }
            do {
                
                self.indexedAt = try container.decode(ATProtocolDate.self, forKey: .indexedAt)
                
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
                
                if !value.isEmpty {
                    try container.encode(value, forKey: .labels)
                }
                
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
                
                if !value.isEmpty {
                    try container.encode(value, forKey: .embeds)
                }
                
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
            
            if self.uri != other.uri {
                return false
            }
            
            
            if self.cid != other.cid {
                return false
            }
            
            
            if self.author != other.author {
                return false
            }
            
            
            if self.value != other.value {
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
            
            
            if self.indexedAt != other.indexedAt {
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
                
                self.uri = try container.decode(ATProtocolURI.self, forKey: .uri)
                
            } catch {
                LogManager.logError("Decoding error for property 'uri': \(error)")
                throw error
            }
            do {
                
                self.notFound = try container.decode(Bool.self, forKey: .notFound)
                
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
            
            if self.uri != other.uri {
                return false
            }
            
            
            if self.notFound != other.notFound {
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
                
                self.uri = try container.decode(ATProtocolURI.self, forKey: .uri)
                
            } catch {
                LogManager.logError("Decoding error for property 'uri': \(error)")
                throw error
            }
            do {
                
                self.blocked = try container.decode(Bool.self, forKey: .blocked)
                
            } catch {
                LogManager.logError("Decoding error for property 'blocked': \(error)")
                throw error
            }
            do {
                
                self.author = try container.decode(AppBskyFeedDefs.BlockedAuthor.self, forKey: .author)
                
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
            
            if self.uri != other.uri {
                return false
            }
            
            
            if self.blocked != other.blocked {
                return false
            }
            
            
            if self.author != other.author {
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
                
                self.uri = try container.decode(ATProtocolURI.self, forKey: .uri)
                
            } catch {
                LogManager.logError("Decoding error for property 'uri': \(error)")
                throw error
            }
            do {
                
                self.detached = try container.decode(Bool.self, forKey: .detached)
                
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
            
            if self.uri != other.uri {
                return false
            }
            
            
            if self.detached != other.detached {
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
        case .appBskyEmbedRecordViewRecord(let value):
            try container.encode("app.bsky.embed.record#viewRecord", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyEmbedRecordViewNotFound(let value):
            try container.encode("app.bsky.embed.record#viewNotFound", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyEmbedRecordViewBlocked(let value):
            try container.encode("app.bsky.embed.record#viewBlocked", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyEmbedRecordViewDetached(let value):
            try container.encode("app.bsky.embed.record#viewDetached", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyFeedDefsGeneratorView(let value):
            try container.encode("app.bsky.feed.defs#generatorView", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyGraphDefsListView(let value):
            try container.encode("app.bsky.graph.defs#listView", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyLabelerDefsLabelerView(let value):
            try container.encode("app.bsky.labeler.defs#labelerView", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyGraphDefsStarterPackViewBasic(let value):
            try container.encode("app.bsky.graph.defs#starterPackViewBasic", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let container):
            try container.encode(to: encoder)
        
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .appBskyEmbedRecordViewRecord(let value):
            hasher.combine("app.bsky.embed.record#viewRecord")
            hasher.combine(value)
        case .appBskyEmbedRecordViewNotFound(let value):
            hasher.combine("app.bsky.embed.record#viewNotFound")
            hasher.combine(value)
        case .appBskyEmbedRecordViewBlocked(let value):
            hasher.combine("app.bsky.embed.record#viewBlocked")
            hasher.combine(value)
        case .appBskyEmbedRecordViewDetached(let value):
            hasher.combine("app.bsky.embed.record#viewDetached")
            hasher.combine(value)
        case .appBskyFeedDefsGeneratorView(let value):
            hasher.combine("app.bsky.feed.defs#generatorView")
            hasher.combine(value)
        case .appBskyGraphDefsListView(let value):
            hasher.combine("app.bsky.graph.defs#listView")
            hasher.combine(value)
        case .appBskyLabelerDefsLabelerView(let value):
            hasher.combine("app.bsky.labeler.defs#labelerView")
            hasher.combine(value)
        case .appBskyGraphDefsStarterPackViewBasic(let value):
            hasher.combine("app.bsky.graph.defs#starterPackViewBasic")
            hasher.combine(value)
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: ViewRecordUnion, rhs: ViewRecordUnion) -> Bool {
        switch (lhs, rhs) {
        case (.appBskyEmbedRecordViewRecord(let lhsValue),
              .appBskyEmbedRecordViewRecord(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyEmbedRecordViewNotFound(let lhsValue),
              .appBskyEmbedRecordViewNotFound(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyEmbedRecordViewBlocked(let lhsValue),
              .appBskyEmbedRecordViewBlocked(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyEmbedRecordViewDetached(let lhsValue),
              .appBskyEmbedRecordViewDetached(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyFeedDefsGeneratorView(let lhsValue),
              .appBskyFeedDefsGeneratorView(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyGraphDefsListView(let lhsValue),
              .appBskyGraphDefsListView(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyLabelerDefsLabelerView(let lhsValue),
              .appBskyLabelerDefsLabelerView(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyGraphDefsStarterPackViewBasic(let lhsValue),
              .appBskyGraphDefsStarterPackViewBasic(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? ViewRecordUnion else { return false }
        return self == other
    }
    
    /// Property that indicates if this enum contains pending data that needs loading
    public var hasPendingData: Bool {
        switch self {
        
        case .appBskyEmbedRecordViewRecord(let value):
            return value.hasPendingData
        case .appBskyEmbedRecordViewNotFound(let value):
            return value.hasPendingData
        case .appBskyEmbedRecordViewBlocked(let value):
            return value.hasPendingData
        case .appBskyEmbedRecordViewDetached(let value):
            return value.hasPendingData
        case .appBskyFeedDefsGeneratorView(let value):
            return value.hasPendingData
        case .appBskyGraphDefsListView(let value):
            return value.hasPendingData
        case .appBskyLabelerDefsLabelerView(let value):
            return value.hasPendingData
        case .appBskyGraphDefsStarterPackViewBasic(let value):
            return value.hasPendingData
        case .unexpected:
            return false
        }
    }
    
    /// Attempts to load any pending data in this enum or its children
    public mutating func loadPendingData() async {
        switch self {
        
        case .appBskyEmbedRecordViewRecord(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyEmbedRecordViewRecord(value)
        case .appBskyEmbedRecordViewNotFound(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyEmbedRecordViewNotFound(value)
        case .appBskyEmbedRecordViewBlocked(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyEmbedRecordViewBlocked(value)
        case .appBskyEmbedRecordViewDetached(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyEmbedRecordViewDetached(value)
        case .appBskyFeedDefsGeneratorView(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyFeedDefsGeneratorView(value)
        case .appBskyGraphDefsListView(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyGraphDefsListView(value)
        case .appBskyLabelerDefsLabelerView(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyLabelerDefsLabelerView(value)
        case .appBskyGraphDefsStarterPackViewBasic(var value):
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
        case .appBskyEmbedImagesView(let value):
            try container.encode("app.bsky.embed.images#view", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyEmbedVideoView(let value):
            try container.encode("app.bsky.embed.video#view", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyEmbedExternalView(let value):
            try container.encode("app.bsky.embed.external#view", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyEmbedRecordView(let value):
            try container.encode("app.bsky.embed.record#view", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyEmbedRecordWithMediaView(let value):
            try container.encode("app.bsky.embed.recordWithMedia#view", forKey: .type)
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
        case .appBskyEmbedRecordView(let value):
            hasher.combine("app.bsky.embed.record#view")
            hasher.combine(value)
        case .appBskyEmbedRecordWithMediaView(let value):
            hasher.combine("app.bsky.embed.recordWithMedia#view")
            hasher.combine(value)
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: ViewRecordEmbedsUnion, rhs: ViewRecordEmbedsUnion) -> Bool {
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
        case (.appBskyEmbedRecordView(let lhsValue),
              .appBskyEmbedRecordView(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyEmbedRecordWithMediaView(let lhsValue),
              .appBskyEmbedRecordWithMediaView(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? ViewRecordEmbedsUnion else { return false }
        return self == other
    }
    
    /// Property that indicates if this enum contains pending data that needs loading
    public var hasPendingData: Bool {
        switch self {
        
        case .appBskyEmbedImagesView(let value):
            return value.hasPendingData
        case .appBskyEmbedVideoView(let value):
            return value.hasPendingData
        case .appBskyEmbedExternalView(let value):
            return value.hasPendingData
        case .appBskyEmbedRecordView(let value):
            return value.hasPendingData
        case .appBskyEmbedRecordWithMediaView(let value):
            return value.hasPendingData
        case .unexpected:
            return false
        }
    }
    
    /// Attempts to load any pending data in this enum or its children
    public mutating func loadPendingData() async {
        switch self {
        
        case .appBskyEmbedImagesView(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyEmbedImagesView(value)
        case .appBskyEmbedVideoView(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyEmbedVideoView(value)
        case .appBskyEmbedExternalView(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyEmbedExternalView(value)
        case .appBskyEmbedRecordView(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyEmbedRecordView(value)
        case .appBskyEmbedRecordWithMediaView(var value):
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


                           
