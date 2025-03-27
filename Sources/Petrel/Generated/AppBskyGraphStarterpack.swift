import Foundation

// lexicon: 1, id: app.bsky.graph.starterpack

public struct AppBskyGraphStarterpack: ATProtocolCodable, ATProtocolValue {
    public static let typeIdentifier = "app.bsky.graph.starterpack"
    public let name: String
    public let description: String?
    public let descriptionFacets: [AppBskyRichtextFacet]?
    public let list: ATProtocolURI
    public let feeds: [FeedItem]?
    public let createdAt: ATProtocolDate

    // Standard initializer
    public init(name: String, description: String?, descriptionFacets: [AppBskyRichtextFacet]?, list: ATProtocolURI, feeds: [FeedItem]?, createdAt: ATProtocolDate) {
        self.name = name

        self.description = description

        self.descriptionFacets = descriptionFacets

        self.list = list

        self.feeds = feeds

        self.createdAt = createdAt
    }

    // Codable initializer
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        name = try container.decode(String.self, forKey: .name)

        description = try container.decodeIfPresent(String.self, forKey: .description)

        descriptionFacets = try container.decodeIfPresent([AppBskyRichtextFacet].self, forKey: .descriptionFacets)

        list = try container.decode(ATProtocolURI.self, forKey: .list)

        feeds = try container.decodeIfPresent([FeedItem].self, forKey: .feeds)

        createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Encode the $type field
        try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

        try container.encode(name, forKey: .name)

        if let value = description {
            try container.encode(value, forKey: .description)
        }

        if let value = descriptionFacets {
            if !value.isEmpty {
                try container.encode(value, forKey: .descriptionFacets)
            }
        }

        try container.encode(list, forKey: .list)

        if let value = feeds {
            if !value.isEmpty {
                try container.encode(value, forKey: .feeds)
            }
        }

        try container.encode(createdAt, forKey: .createdAt)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.isEqual(to: rhs)
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? Self else { return false }

        if name != other.name {
            return false
        }

        if description != other.description {
            return false
        }

        if descriptionFacets != other.descriptionFacets {
            return false
        }

        if list != other.list {
            return false
        }

        if feeds != other.feeds {
            return false
        }

        if createdAt != other.createdAt {
            return false
        }

        return true
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        if let value = description {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?) // Placeholder for nil
        }
        if let value = descriptionFacets {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?) // Placeholder for nil
        }
        hasher.combine(list)
        if let value = feeds {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?) // Placeholder for nil
        }
        hasher.combine(createdAt)
    }

    private enum CodingKeys: String, CodingKey {
        case typeIdentifier = "$type"
        case name
        case description
        case descriptionFacets
        case list
        case feeds
        case createdAt
    }

    // MARK: - PendingDataLoadable

    /// Check if any properties contain pending data that needs loading
    public var hasPendingData: Bool {
        var hasPending = false

        if !hasPending, let loadable = name as? PendingDataLoadable {
            hasPending = loadable.hasPendingData
        }

        if !hasPending, let value = description, let loadable = value as? PendingDataLoadable {
            hasPending = loadable.hasPendingData
        }

        if !hasPending, let value = descriptionFacets, let loadable = value as? PendingDataLoadable {
            hasPending = loadable.hasPendingData
        }

        if !hasPending, let loadable = list as? PendingDataLoadable {
            hasPending = loadable.hasPendingData
        }

        if !hasPending, let value = feeds, let loadable = value as? PendingDataLoadable {
            hasPending = loadable.hasPendingData
        }

        if !hasPending, let loadable = createdAt as? PendingDataLoadable {
            hasPending = loadable.hasPendingData
        }

        return hasPending
    }

    /// Load any pending data in properties
    public mutating func loadPendingData() async {
        if let loadable = name as? PendingDataLoadable, loadable.hasPendingData {
            var mutableValue = loadable
            await mutableValue.loadPendingData()
            // Only update if we can safely cast back to the expected type
            if let updatedValue = mutableValue as? String {
                name = updatedValue
            }
        }

        if var value = description as? (String & PendingDataLoadable), value.hasPendingData {
            await value.loadPendingData()
            description = value
        }

        if var value = descriptionFacets as? ([AppBskyRichtextFacet] & PendingDataLoadable), value.hasPendingData {
            await value.loadPendingData()
            descriptionFacets = value
        }

        if let loadable = list as? PendingDataLoadable, loadable.hasPendingData {
            var mutableValue = loadable
            await mutableValue.loadPendingData()
            // Only update if we can safely cast back to the expected type
            if let updatedValue = mutableValue as? ATProtocolURI {
                list = updatedValue
            }
        }

        if var value = feeds as? ([FeedItem] & PendingDataLoadable), value.hasPendingData {
            await value.loadPendingData()
            feeds = value
        }

        if let loadable = createdAt as? PendingDataLoadable, loadable.hasPendingData {
            var mutableValue = loadable
            await mutableValue.loadPendingData()
            // Only update if we can safely cast back to the expected type
            if let updatedValue = mutableValue as? ATProtocolDate {
                createdAt = updatedValue
            }
        }
    }

    public struct FeedItem: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.graph.starterpack#feedItem"
        public let uri: ATProtocolURI

        // Standard initializer
        public init(
            uri: ATProtocolURI
        ) {
            self.uri = uri
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

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
        }

        // MARK: - PendingDataLoadable

        /// Check if any properties contain pending data that needs loading
        public var hasPendingData: Bool {
            var hasPending = false

            if !hasPending, let loadable = uri as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            return hasPending
        }

        /// Load any pending data in properties
        public mutating func loadPendingData() async {
            if let loadable = uri as? PendingDataLoadable, loadable.hasPendingData {
                var mutableValue = loadable
                await mutableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = mutableValue as? ATProtocolURI {
                    uri = updatedValue
                }
            }
        }
    }
}
