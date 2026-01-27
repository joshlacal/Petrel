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

    public func toCBORValue() throws -> Any {
        var map = OrderedCBORMap()
        let externalValue = try external.toCBORValue()
        map = map.adding(key: "external", value: externalValue)
        return map
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

        public init(
            uri: URI, title: String, description: String, thumb: Blob?
        ) {
            self.uri = uri
            self.title = title
            self.description = description
            self.thumb = thumb
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                uri = try container.decode(URI.self, forKey: .uri)
            } catch {
                LogManager.logError("Decoding error for required property 'uri': \(error)")
                throw error
            }
            do {
                title = try container.decode(String.self, forKey: .title)
            } catch {
                LogManager.logError("Decoding error for required property 'title': \(error)")
                throw error
            }
            do {
                description = try container.decode(String.self, forKey: .description)
            } catch {
                LogManager.logError("Decoding error for required property 'description': \(error)")
                throw error
            }
            do {
                thumb = try container.decodeIfPresent(Blob.self, forKey: .thumb)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'thumb': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(uri, forKey: .uri)
            try container.encode(title, forKey: .title)
            try container.encode(description, forKey: .description)
            try container.encodeIfPresent(thumb, forKey: .thumb)
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

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let uriValue = try uri.toCBORValue()
            map = map.adding(key: "uri", value: uriValue)
            let titleValue = try title.toCBORValue()
            map = map.adding(key: "title", value: titleValue)
            let descriptionValue = try description.toCBORValue()
            map = map.adding(key: "description", value: descriptionValue)
            if let value = thumb {
                let thumbValue = try value.toCBORValue()
                map = map.adding(key: "thumb", value: thumbValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
            case title
            case description
            case thumb
        }
    }

    public struct View: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.embed.external#view"
        public let external: ViewExternal

        public init(
            external: ViewExternal
        ) {
            self.external = external
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                external = try container.decode(ViewExternal.self, forKey: .external)
            } catch {
                LogManager.logError("Decoding error for required property 'external': \(error)")
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

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let externalValue = try external.toCBORValue()
            map = map.adding(key: "external", value: externalValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case external
        }
    }

    public struct ViewExternal: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.embed.external#viewExternal"
        public let uri: URI
        public let title: String
        public let description: String
        public let thumb: URI?

        public init(
            uri: URI, title: String, description: String, thumb: URI?
        ) {
            self.uri = uri
            self.title = title
            self.description = description
            self.thumb = thumb
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                uri = try container.decode(URI.self, forKey: .uri)
            } catch {
                LogManager.logError("Decoding error for required property 'uri': \(error)")
                throw error
            }
            do {
                title = try container.decode(String.self, forKey: .title)
            } catch {
                LogManager.logError("Decoding error for required property 'title': \(error)")
                throw error
            }
            do {
                description = try container.decode(String.self, forKey: .description)
            } catch {
                LogManager.logError("Decoding error for required property 'description': \(error)")
                throw error
            }
            do {
                thumb = try container.decodeIfPresent(URI.self, forKey: .thumb)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'thumb': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(uri, forKey: .uri)
            try container.encode(title, forKey: .title)
            try container.encode(description, forKey: .description)
            try container.encodeIfPresent(thumb, forKey: .thumb)
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

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let uriValue = try uri.toCBORValue()
            map = map.adding(key: "uri", value: uriValue)
            let titleValue = try title.toCBORValue()
            map = map.adding(key: "title", value: titleValue)
            let descriptionValue = try description.toCBORValue()
            map = map.adding(key: "description", value: descriptionValue)
            if let value = thumb {
                let thumbValue = try value.toCBORValue()
                map = map.adding(key: "thumb", value: thumbValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
            case title
            case description
            case thumb
        }
    }
}
