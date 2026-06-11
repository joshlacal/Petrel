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
        public let associatedRefs: [ComAtprotoRepoStrongRef]?

        public init(
            uri: URI, title: String, description: String, thumb: Blob?, associatedRefs: [ComAtprotoRepoStrongRef]?
        ) {
            self.uri = uri
            self.title = title
            self.description = description
            self.thumb = thumb
            self.associatedRefs = associatedRefs
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
                // Forward compatibility: a malformed or unknown-shaped optional field
                // must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'thumb' — degrading to nil: \(error)")
                thumb = nil
            }
            do {
                associatedRefs = try container.decodeIfPresent([ComAtprotoRepoStrongRef].self, forKey: .associatedRefs)
            } catch {
                // Forward compatibility: a malformed or unknown-shaped optional field
                // must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'associatedRefs' — degrading to nil: \(error)")
                associatedRefs = nil
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(uri, forKey: .uri)
            try container.encode(title, forKey: .title)
            try container.encode(description, forKey: .description)
            try container.encodeIfPresent(thumb, forKey: .thumb)
            try container.encodeIfPresent(associatedRefs, forKey: .associatedRefs)
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
            if let value = associatedRefs {
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
            if associatedRefs != other.associatedRefs {
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
            if let value = associatedRefs {
                let associatedRefsValue = try value.toCBORValue()
                map = map.adding(key: "associatedRefs", value: associatedRefsValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
            case title
            case description
            case thumb
            case associatedRefs
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
        public let createdAt: ATProtocolDate?
        public let updatedAt: ATProtocolDate?
        public let readingTime: Int?
        public let labels: [ComAtprotoLabelDefs.Label]?
        public let source: ViewExternalSource?
        public let associatedRefs: [ComAtprotoRepoStrongRef]?
        public let associatedProfiles: [AppBskyActorDefs.ProfileViewBasic]?

        public init(
            uri: URI, title: String, description: String, thumb: URI?, createdAt: ATProtocolDate?, updatedAt: ATProtocolDate?, readingTime: Int?, labels: [ComAtprotoLabelDefs.Label]?, source: ViewExternalSource?, associatedRefs: [ComAtprotoRepoStrongRef]?, associatedProfiles: [AppBskyActorDefs.ProfileViewBasic]?
        ) {
            self.uri = uri
            self.title = title
            self.description = description
            self.thumb = thumb
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.readingTime = readingTime
            self.labels = labels
            self.source = source
            self.associatedRefs = associatedRefs
            self.associatedProfiles = associatedProfiles
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
                // Forward compatibility: a malformed or unknown-shaped optional field
                // must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'thumb' — degrading to nil: \(error)")
                thumb = nil
            }
            do {
                createdAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .createdAt)
            } catch {
                // Forward compatibility: a malformed or unknown-shaped optional field
                // must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'createdAt' — degrading to nil: \(error)")
                createdAt = nil
            }
            do {
                updatedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .updatedAt)
            } catch {
                // Forward compatibility: a malformed or unknown-shaped optional field
                // must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'updatedAt' — degrading to nil: \(error)")
                updatedAt = nil
            }
            do {
                readingTime = try container.decodeIfPresent(Int.self, forKey: .readingTime)
            } catch {
                // Forward compatibility: a malformed or unknown-shaped optional field
                // must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'readingTime' — degrading to nil: \(error)")
                readingTime = nil
            }
            do {
                labels = try container.decodeIfPresent([ComAtprotoLabelDefs.Label].self, forKey: .labels)
            } catch {
                // Forward compatibility: a malformed or unknown-shaped optional field
                // must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'labels' — degrading to nil: \(error)")
                labels = nil
            }
            do {
                source = try container.decodeIfPresent(ViewExternalSource.self, forKey: .source)
            } catch {
                // Forward compatibility: a malformed or unknown-shaped optional field
                // must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'source' — degrading to nil: \(error)")
                source = nil
            }
            do {
                associatedRefs = try container.decodeIfPresent([ComAtprotoRepoStrongRef].self, forKey: .associatedRefs)
            } catch {
                // Forward compatibility: a malformed or unknown-shaped optional field
                // must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'associatedRefs' — degrading to nil: \(error)")
                associatedRefs = nil
            }
            do {
                associatedProfiles = try container.decodeIfPresent([AppBskyActorDefs.ProfileViewBasic].self, forKey: .associatedProfiles)
            } catch {
                // Forward compatibility: a malformed or unknown-shaped optional field
                // must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'associatedProfiles' — degrading to nil: \(error)")
                associatedProfiles = nil
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(uri, forKey: .uri)
            try container.encode(title, forKey: .title)
            try container.encode(description, forKey: .description)
            try container.encodeIfPresent(thumb, forKey: .thumb)
            try container.encodeIfPresent(createdAt, forKey: .createdAt)
            try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
            try container.encodeIfPresent(readingTime, forKey: .readingTime)
            try container.encodeIfPresent(labels, forKey: .labels)
            try container.encodeIfPresent(source, forKey: .source)
            try container.encodeIfPresent(associatedRefs, forKey: .associatedRefs)
            try container.encodeIfPresent(associatedProfiles, forKey: .associatedProfiles)
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
            if let value = createdAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = updatedAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = readingTime {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = labels {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = source {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = associatedRefs {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = associatedProfiles {
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
            if createdAt != other.createdAt {
                return false
            }
            if updatedAt != other.updatedAt {
                return false
            }
            if readingTime != other.readingTime {
                return false
            }
            if labels != other.labels {
                return false
            }
            if source != other.source {
                return false
            }
            if associatedRefs != other.associatedRefs {
                return false
            }
            if associatedProfiles != other.associatedProfiles {
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
            if let value = createdAt {
                let createdAtValue = try value.toCBORValue()
                map = map.adding(key: "createdAt", value: createdAtValue)
            }
            if let value = updatedAt {
                let updatedAtValue = try value.toCBORValue()
                map = map.adding(key: "updatedAt", value: updatedAtValue)
            }
            if let value = readingTime {
                let readingTimeValue = try value.toCBORValue()
                map = map.adding(key: "readingTime", value: readingTimeValue)
            }
            if let value = labels {
                let labelsValue = try value.toCBORValue()
                map = map.adding(key: "labels", value: labelsValue)
            }
            if let value = source {
                let sourceValue = try value.toCBORValue()
                map = map.adding(key: "source", value: sourceValue)
            }
            if let value = associatedRefs {
                let associatedRefsValue = try value.toCBORValue()
                map = map.adding(key: "associatedRefs", value: associatedRefsValue)
            }
            if let value = associatedProfiles {
                let associatedProfilesValue = try value.toCBORValue()
                map = map.adding(key: "associatedProfiles", value: associatedProfilesValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
            case title
            case description
            case thumb
            case createdAt
            case updatedAt
            case readingTime
            case labels
            case source
            case associatedRefs
            case associatedProfiles
        }
    }

    public struct ViewExternalSource: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.embed.external#viewExternalSource"
        public let uri: URI
        public let icon: URI?
        public let title: String
        public let description: String?
        public let theme: ViewExternalSourceTheme?

        public init(
            uri: URI, icon: URI?, title: String, description: String?, theme: ViewExternalSourceTheme?
        ) {
            self.uri = uri
            self.icon = icon
            self.title = title
            self.description = description
            self.theme = theme
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
                icon = try container.decodeIfPresent(URI.self, forKey: .icon)
            } catch {
                // Forward compatibility: a malformed or unknown-shaped optional field
                // must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'icon' — degrading to nil: \(error)")
                icon = nil
            }
            do {
                title = try container.decode(String.self, forKey: .title)
            } catch {
                LogManager.logError("Decoding error for required property 'title': \(error)")
                throw error
            }
            do {
                description = try container.decodeIfPresent(String.self, forKey: .description)
            } catch {
                // Forward compatibility: a malformed or unknown-shaped optional field
                // must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'description' — degrading to nil: \(error)")
                description = nil
            }
            do {
                theme = try container.decodeIfPresent(ViewExternalSourceTheme.self, forKey: .theme)
            } catch {
                // Forward compatibility: a malformed or unknown-shaped optional field
                // must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'theme' — degrading to nil: \(error)")
                theme = nil
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(uri, forKey: .uri)
            try container.encodeIfPresent(icon, forKey: .icon)
            try container.encode(title, forKey: .title)
            try container.encodeIfPresent(description, forKey: .description)
            try container.encodeIfPresent(theme, forKey: .theme)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
            if let value = icon {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(title)
            if let value = description {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = theme {
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
            if icon != other.icon {
                return false
            }
            if title != other.title {
                return false
            }
            if description != other.description {
                return false
            }
            if theme != other.theme {
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
            if let value = icon {
                let iconValue = try value.toCBORValue()
                map = map.adding(key: "icon", value: iconValue)
            }
            let titleValue = try title.toCBORValue()
            map = map.adding(key: "title", value: titleValue)
            if let value = description {
                let descriptionValue = try value.toCBORValue()
                map = map.adding(key: "description", value: descriptionValue)
            }
            if let value = theme {
                let themeValue = try value.toCBORValue()
                map = map.adding(key: "theme", value: themeValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
            case icon
            case title
            case description
            case theme
        }
    }

    public struct ViewExternalSourceTheme: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.embed.external#viewExternalSourceTheme"
        public let backgroundRGB: ColorRGB?
        public let foregroundRGB: ColorRGB?
        public let accentRGB: ColorRGB?
        public let accentForegroundRGB: ColorRGB?

        public init(
            backgroundRGB: ColorRGB?, foregroundRGB: ColorRGB?, accentRGB: ColorRGB?, accentForegroundRGB: ColorRGB?
        ) {
            self.backgroundRGB = backgroundRGB
            self.foregroundRGB = foregroundRGB
            self.accentRGB = accentRGB
            self.accentForegroundRGB = accentForegroundRGB
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                backgroundRGB = try container.decodeIfPresent(ColorRGB.self, forKey: .backgroundRGB)
            } catch {
                // Forward compatibility: a malformed or unknown-shaped optional field
                // must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'backgroundRGB' — degrading to nil: \(error)")
                backgroundRGB = nil
            }
            do {
                foregroundRGB = try container.decodeIfPresent(ColorRGB.self, forKey: .foregroundRGB)
            } catch {
                // Forward compatibility: a malformed or unknown-shaped optional field
                // must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'foregroundRGB' — degrading to nil: \(error)")
                foregroundRGB = nil
            }
            do {
                accentRGB = try container.decodeIfPresent(ColorRGB.self, forKey: .accentRGB)
            } catch {
                // Forward compatibility: a malformed or unknown-shaped optional field
                // must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'accentRGB' — degrading to nil: \(error)")
                accentRGB = nil
            }
            do {
                accentForegroundRGB = try container.decodeIfPresent(ColorRGB.self, forKey: .accentForegroundRGB)
            } catch {
                // Forward compatibility: a malformed or unknown-shaped optional field
                // must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'accentForegroundRGB' — degrading to nil: \(error)")
                accentForegroundRGB = nil
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encodeIfPresent(backgroundRGB, forKey: .backgroundRGB)
            try container.encodeIfPresent(foregroundRGB, forKey: .foregroundRGB)
            try container.encodeIfPresent(accentRGB, forKey: .accentRGB)
            try container.encodeIfPresent(accentForegroundRGB, forKey: .accentForegroundRGB)
        }

        public func hash(into hasher: inout Hasher) {
            if let value = backgroundRGB {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = foregroundRGB {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = accentRGB {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = accentForegroundRGB {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if backgroundRGB != other.backgroundRGB {
                return false
            }
            if foregroundRGB != other.foregroundRGB {
                return false
            }
            if accentRGB != other.accentRGB {
                return false
            }
            if accentForegroundRGB != other.accentForegroundRGB {
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
            if let value = backgroundRGB {
                let backgroundRGBValue = try value.toCBORValue()
                map = map.adding(key: "backgroundRGB", value: backgroundRGBValue)
            }
            if let value = foregroundRGB {
                let foregroundRGBValue = try value.toCBORValue()
                map = map.adding(key: "foregroundRGB", value: foregroundRGBValue)
            }
            if let value = accentRGB {
                let accentRGBValue = try value.toCBORValue()
                map = map.adding(key: "accentRGB", value: accentRGBValue)
            }
            if let value = accentForegroundRGB {
                let accentForegroundRGBValue = try value.toCBORValue()
                map = map.adding(key: "accentForegroundRGB", value: accentForegroundRGBValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case backgroundRGB
            case foregroundRGB
            case accentRGB
            case accentForegroundRGB
        }
    }

    public struct ColorRGB: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.embed.external#colorRGB"
        public let r: Int
        public let g: Int
        public let b: Int

        public init(
            r: Int, g: Int, b: Int
        ) {
            self.r = r
            self.g = g
            self.b = b
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                r = try container.decode(Int.self, forKey: .r)
            } catch {
                LogManager.logError("Decoding error for required property 'r': \(error)")
                throw error
            }
            do {
                g = try container.decode(Int.self, forKey: .g)
            } catch {
                LogManager.logError("Decoding error for required property 'g': \(error)")
                throw error
            }
            do {
                b = try container.decode(Int.self, forKey: .b)
            } catch {
                LogManager.logError("Decoding error for required property 'b': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(r, forKey: .r)
            try container.encode(g, forKey: .g)
            try container.encode(b, forKey: .b)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(r)
            hasher.combine(g)
            hasher.combine(b)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if r != other.r {
                return false
            }
            if g != other.g {
                return false
            }
            if b != other.b {
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
            let rValue = try r.toCBORValue()
            map = map.adding(key: "r", value: rValue)
            let gValue = try g.toCBORValue()
            map = map.adding(key: "g", value: gValue)
            let bValue = try b.toCBORValue()
            map = map.adding(key: "b", value: bValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case r
            case g
            case b
        }
    }
}
