import Foundation



// lexicon: 1, id: place.stream.server.defs


public struct PlaceStreamServerDefs { 

    public static let typeIdentifier = "place.stream.server.defs"
        
public struct Webhook: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "place.stream.server.defs#webhook"
            public let id: String
            public let url: URI
            public let events: [String]
            public let active: Bool
            public let prefix: String?
            public let suffix: String?
            public let rewrite: [RewriteRule]?
            public let createdAt: ATProtocolDate
            public let updatedAt: ATProtocolDate?
            public let name: String?
            public let description: String?
            public let lastTriggered: ATProtocolDate?
            public let errorCount: Int?
            public let muteWords: [String]?

        public init(
            id: String, url: URI, events: [String], active: Bool, prefix: String?, suffix: String?, rewrite: [RewriteRule]?, createdAt: ATProtocolDate, updatedAt: ATProtocolDate?, name: String?, description: String?, lastTriggered: ATProtocolDate?, errorCount: Int?, muteWords: [String]?
        ) {
            self.id = id
            self.url = url
            self.events = events
            self.active = active
            self.prefix = prefix
            self.suffix = suffix
            self.rewrite = rewrite
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.name = name
            self.description = description
            self.lastTriggered = lastTriggered
            self.errorCount = errorCount
            self.muteWords = muteWords
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.id = try container.decode(String.self, forKey: .id)
            } catch {
                LogManager.logError("Decoding error for required property 'id': \(error)")
                throw error
            }
            do {
                self.url = try container.decode(URI.self, forKey: .url)
            } catch {
                LogManager.logError("Decoding error for required property 'url': \(error)")
                throw error
            }
            do {
                self.events = try container.decode([String].self, forKey: .events)
            } catch {
                LogManager.logError("Decoding error for required property 'events': \(error)")
                throw error
            }
            do {
                self.active = try container.decode(Bool.self, forKey: .active)
            } catch {
                LogManager.logError("Decoding error for required property 'active': \(error)")
                throw error
            }
            do {
                self.prefix = try container.decodeIfPresent(String.self, forKey: .prefix)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'prefix': \(error)")
                throw error
            }
            do {
                self.suffix = try container.decodeIfPresent(String.self, forKey: .suffix)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'suffix': \(error)")
                throw error
            }
            do {
                self.rewrite = try container.decodeIfPresent([RewriteRule].self, forKey: .rewrite)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'rewrite': \(error)")
                throw error
            }
            do {
                self.createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
            } catch {
                LogManager.logError("Decoding error for required property 'createdAt': \(error)")
                throw error
            }
            do {
                self.updatedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .updatedAt)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'updatedAt': \(error)")
                throw error
            }
            do {
                self.name = try container.decodeIfPresent(String.self, forKey: .name)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'name': \(error)")
                throw error
            }
            do {
                self.description = try container.decodeIfPresent(String.self, forKey: .description)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'description': \(error)")
                throw error
            }
            do {
                self.lastTriggered = try container.decodeIfPresent(ATProtocolDate.self, forKey: .lastTriggered)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'lastTriggered': \(error)")
                throw error
            }
            do {
                self.errorCount = try container.decodeIfPresent(Int.self, forKey: .errorCount)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'errorCount': \(error)")
                throw error
            }
            do {
                self.muteWords = try container.decodeIfPresent([String].self, forKey: .muteWords)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'muteWords': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(id, forKey: .id)
            try container.encode(url, forKey: .url)
            try container.encode(events, forKey: .events)
            try container.encode(active, forKey: .active)
            try container.encodeIfPresent(prefix, forKey: .prefix)
            try container.encodeIfPresent(suffix, forKey: .suffix)
            try container.encodeIfPresent(rewrite, forKey: .rewrite)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
            try container.encodeIfPresent(name, forKey: .name)
            try container.encodeIfPresent(description, forKey: .description)
            try container.encodeIfPresent(lastTriggered, forKey: .lastTriggered)
            try container.encodeIfPresent(errorCount, forKey: .errorCount)
            try container.encodeIfPresent(muteWords, forKey: .muteWords)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(url)
            hasher.combine(events)
            hasher.combine(active)
            if let value = prefix {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = suffix {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = rewrite {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(createdAt)
            if let value = updatedAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = name {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = description {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = lastTriggered {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = errorCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = muteWords {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if id != other.id {
                return false
            }
            if url != other.url {
                return false
            }
            if events != other.events {
                return false
            }
            if active != other.active {
                return false
            }
            if prefix != other.prefix {
                return false
            }
            if suffix != other.suffix {
                return false
            }
            if rewrite != other.rewrite {
                return false
            }
            if createdAt != other.createdAt {
                return false
            }
            if updatedAt != other.updatedAt {
                return false
            }
            if name != other.name {
                return false
            }
            if description != other.description {
                return false
            }
            if lastTriggered != other.lastTriggered {
                return false
            }
            if errorCount != other.errorCount {
                return false
            }
            if muteWords != other.muteWords {
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
            let urlValue = try url.toCBORValue()
            map = map.adding(key: "url", value: urlValue)
            let eventsValue = try events.toCBORValue()
            map = map.adding(key: "events", value: eventsValue)
            let activeValue = try active.toCBORValue()
            map = map.adding(key: "active", value: activeValue)
            if let value = prefix {
                let prefixValue = try value.toCBORValue()
                map = map.adding(key: "prefix", value: prefixValue)
            }
            if let value = suffix {
                let suffixValue = try value.toCBORValue()
                map = map.adding(key: "suffix", value: suffixValue)
            }
            if let value = rewrite {
                let rewriteValue = try value.toCBORValue()
                map = map.adding(key: "rewrite", value: rewriteValue)
            }
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            if let value = updatedAt {
                let updatedAtValue = try value.toCBORValue()
                map = map.adding(key: "updatedAt", value: updatedAtValue)
            }
            if let value = name {
                let nameValue = try value.toCBORValue()
                map = map.adding(key: "name", value: nameValue)
            }
            if let value = description {
                let descriptionValue = try value.toCBORValue()
                map = map.adding(key: "description", value: descriptionValue)
            }
            if let value = lastTriggered {
                let lastTriggeredValue = try value.toCBORValue()
                map = map.adding(key: "lastTriggered", value: lastTriggeredValue)
            }
            if let value = errorCount {
                let errorCountValue = try value.toCBORValue()
                map = map.adding(key: "errorCount", value: errorCountValue)
            }
            if let value = muteWords {
                let muteWordsValue = try value.toCBORValue()
                map = map.adding(key: "muteWords", value: muteWordsValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case id
            case url
            case events
            case active
            case prefix
            case suffix
            case rewrite
            case createdAt
            case updatedAt
            case name
            case description
            case lastTriggered
            case errorCount
            case muteWords
        }
    }
        
public struct RewriteRule: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "place.stream.server.defs#rewriteRule"
            public let from: String
            public let to: String

        public init(
            from: String, to: String
        ) {
            self.from = from
            self.to = to
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.from = try container.decode(String.self, forKey: .from)
            } catch {
                LogManager.logError("Decoding error for required property 'from': \(error)")
                throw error
            }
            do {
                self.to = try container.decode(String.self, forKey: .to)
            } catch {
                LogManager.logError("Decoding error for required property 'to': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(from, forKey: .from)
            try container.encode(to, forKey: .to)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(from)
            hasher.combine(to)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if from != other.from {
                return false
            }
            if to != other.to {
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
            let fromValue = try from.toCBORValue()
            map = map.adding(key: "from", value: fromValue)
            let toValue = try to.toCBORValue()
            map = map.adding(key: "to", value: toValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case from
            case to
        }
    }



}


                           

