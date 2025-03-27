import Foundation

// lexicon: 1, id: app.bsky.embed.external

public struct AppBskyEmbedExternal: ATProtocolCodable, ATProtocolValue {
    public static let typeIdentifier = "app.bsky.embed.external"
    public let external: External

    public init(external: External) {
        self.external = external
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        external = try container.decode(External.self, forKey: .external)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(external, forKey: .external)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(external)
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? Self else { return false }
        if external != other.external {
            return false
        }
        return true
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.isEqual(to: rhs)
    }

    private enum CodingKeys: String, CodingKey {
        case external
    }

    public struct External: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.embed.external#external"
        public let uri: URI
        public let title: String
        public let description: String
        public let thumb: Blob?

        // Standard initializer
        public init(
            uri: URI, title: String, description: String, thumb: Blob?
        ) {
            self.uri = uri
            self.title = title
            self.description = description
            self.thumb = thumb
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                uri = try container.decode(URI.self, forKey: .uri)

            } catch {
                LogManager.logError("Decoding error for property 'uri': \(error)")
                throw error
            }
            do {
                title = try container.decode(String.self, forKey: .title)

            } catch {
                LogManager.logError("Decoding error for property 'title': \(error)")
                throw error
            }
            do {
                description = try container.decode(String.self, forKey: .description)

            } catch {
                LogManager.logError("Decoding error for property 'description': \(error)")
                throw error
            }
            do {
                thumb = try container.decodeIfPresent(Blob.self, forKey: .thumb)

            } catch {
                LogManager.logError("Decoding error for property 'thumb': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(uri, forKey: .uri)

            try container.encode(title, forKey: .title)

            try container.encode(description, forKey: .description)

            if let value = thumb {
                try container.encode(value, forKey: .thumb)
            }
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
            hasher.combine(title)
            hasher.combine(description)
            if let value = thumb {
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

            if title != other.title {
                return false
            }

            if description != other.description {
                return false
            }

            if thumb != other.thumb {
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
            case title
            case description
            case thumb
        }

        // MARK: - PendingDataLoadable

        /// Check if any properties contain pending data that needs loading
        public var hasPendingData: Bool {
            var hasPending = false

            if !hasPending, let loadable = uri as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let loadable = title as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let loadable = description as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let value = thumb, let loadable = value as? PendingDataLoadable {
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
                if let updatedValue = mutableValue as? URI {
                    uri = updatedValue
                }
            }

            if let loadable = title as? PendingDataLoadable, loadable.hasPendingData {
                var mutableValue = loadable
                await mutableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = mutableValue as? String {
                    title = updatedValue
                }
            }

            if let loadable = description as? PendingDataLoadable, loadable.hasPendingData {
                var mutableValue = loadable
                await mutableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = mutableValue as? String {
                    description = updatedValue
                }
            }

            if let value = thumb, var loadableValue = value as? PendingDataLoadable, loadableValue.hasPendingData {
                await loadableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = loadableValue as? Blob {
                    thumb = updatedValue
                }
            }
        }
    }

    public struct View: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.embed.external#view"
        public let external: ViewExternal

        // Standard initializer
        public init(
            external: ViewExternal
        ) {
            self.external = external
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                external = try container.decode(ViewExternal.self, forKey: .external)

            } catch {
                LogManager.logError("Decoding error for property 'external': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(external, forKey: .external)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(external)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if external != other.external {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case external
        }

        // MARK: - PendingDataLoadable

        /// Check if any properties contain pending data that needs loading
        public var hasPendingData: Bool {
            var hasPending = false

            if !hasPending, let loadable = external as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            return hasPending
        }

        /// Load any pending data in properties
        public mutating func loadPendingData() async {
            if let loadable = external as? PendingDataLoadable, loadable.hasPendingData {
                var mutableValue = loadable
                await mutableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = mutableValue as? ViewExternal {
                    external = updatedValue
                }
            }
        }
    }

    public struct ViewExternal: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.embed.external#viewExternal"
        public let uri: URI
        public let title: String
        public let description: String
        public let thumb: URI?

        // Standard initializer
        public init(
            uri: URI, title: String, description: String, thumb: URI?
        ) {
            self.uri = uri
            self.title = title
            self.description = description
            self.thumb = thumb
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                uri = try container.decode(URI.self, forKey: .uri)

            } catch {
                LogManager.logError("Decoding error for property 'uri': \(error)")
                throw error
            }
            do {
                title = try container.decode(String.self, forKey: .title)

            } catch {
                LogManager.logError("Decoding error for property 'title': \(error)")
                throw error
            }
            do {
                description = try container.decode(String.self, forKey: .description)

            } catch {
                LogManager.logError("Decoding error for property 'description': \(error)")
                throw error
            }
            do {
                thumb = try container.decodeIfPresent(URI.self, forKey: .thumb)

            } catch {
                LogManager.logError("Decoding error for property 'thumb': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(uri, forKey: .uri)

            try container.encode(title, forKey: .title)

            try container.encode(description, forKey: .description)

            if let value = thumb {
                try container.encode(value, forKey: .thumb)
            }
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
            hasher.combine(title)
            hasher.combine(description)
            if let value = thumb {
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

            if title != other.title {
                return false
            }

            if description != other.description {
                return false
            }

            if thumb != other.thumb {
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
            case title
            case description
            case thumb
        }

        // MARK: - PendingDataLoadable

        /// Check if any properties contain pending data that needs loading
        public var hasPendingData: Bool {
            var hasPending = false

            if !hasPending, let loadable = uri as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let loadable = title as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let loadable = description as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let value = thumb, let loadable = value as? PendingDataLoadable {
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
                if let updatedValue = mutableValue as? URI {
                    uri = updatedValue
                }
            }

            if let loadable = title as? PendingDataLoadable, loadable.hasPendingData {
                var mutableValue = loadable
                await mutableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = mutableValue as? String {
                    title = updatedValue
                }
            }

            if let loadable = description as? PendingDataLoadable, loadable.hasPendingData {
                var mutableValue = loadable
                await mutableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = mutableValue as? String {
                    description = updatedValue
                }
            }

            if let value = thumb, var loadableValue = value as? PendingDataLoadable, loadableValue.hasPendingData {
                await loadableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = loadableValue as? URI {
                    thumb = updatedValue
                }
            }
        }
    }
}
