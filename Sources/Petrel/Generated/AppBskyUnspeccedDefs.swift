import Foundation

// lexicon: 1, id: app.bsky.unspecced.defs

public enum AppBskyUnspeccedDefs {
    public static let typeIdentifier = "app.bsky.unspecced.defs"

    public struct SkeletonSearchPost: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.unspecced.defs#skeletonSearchPost"
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let uriValue = try (uri as? DAGCBOREncodable)?.toCBORValue() ?? uri
            map = map.adding(key: "uri", value: uriValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
        }
    }

    public struct SkeletonSearchActor: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.unspecced.defs#skeletonSearchActor"
        public let did: DID

        // Standard initializer
        public init(
            did: DID
        ) {
            self.did = did
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                did = try container.decode(DID.self, forKey: .did)

            } catch {
                LogManager.logError("Decoding error for property 'did': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(did, forKey: .did)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(did)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if did != other.did {
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

            let didValue = try (did as? DAGCBOREncodable)?.toCBORValue() ?? did
            map = map.adding(key: "did", value: didValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
        }
    }

    public struct SkeletonSearchStarterPack: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.unspecced.defs#skeletonSearchStarterPack"
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let uriValue = try (uri as? DAGCBOREncodable)?.toCBORValue() ?? uri
            map = map.adding(key: "uri", value: uriValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
        }
    }

    public struct TrendingTopic: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.unspecced.defs#trendingTopic"
        public let topic: String
        public let displayName: String?
        public let description: String?
        public let link: String

        // Standard initializer
        public init(
            topic: String, displayName: String?, description: String?, link: String
        ) {
            self.topic = topic
            self.displayName = displayName
            self.description = description
            self.link = link
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                topic = try container.decode(String.self, forKey: .topic)

            } catch {
                LogManager.logError("Decoding error for property 'topic': \(error)")
                throw error
            }
            do {
                displayName = try container.decodeIfPresent(String.self, forKey: .displayName)

            } catch {
                LogManager.logError("Decoding error for property 'displayName': \(error)")
                throw error
            }
            do {
                description = try container.decodeIfPresent(String.self, forKey: .description)

            } catch {
                LogManager.logError("Decoding error for property 'description': \(error)")
                throw error
            }
            do {
                link = try container.decode(String.self, forKey: .link)

            } catch {
                LogManager.logError("Decoding error for property 'link': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(topic, forKey: .topic)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(displayName, forKey: .displayName)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(description, forKey: .description)

            try container.encode(link, forKey: .link)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(topic)
            if let value = displayName {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = description {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(link)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if topic != other.topic {
                return false
            }

            if displayName != other.displayName {
                return false
            }

            if description != other.description {
                return false
            }

            if link != other.link {
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

            let topicValue = try (topic as? DAGCBOREncodable)?.toCBORValue() ?? topic
            map = map.adding(key: "topic", value: topicValue)

            if let value = displayName {
                // Encode optional property even if it's an empty array for CBOR

                let displayNameValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "displayName", value: displayNameValue)
            }

            if let value = description {
                // Encode optional property even if it's an empty array for CBOR

                let descriptionValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "description", value: descriptionValue)
            }

            let linkValue = try (link as? DAGCBOREncodable)?.toCBORValue() ?? link
            map = map.adding(key: "link", value: linkValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case topic
            case displayName
            case description
            case link
        }
    }

    public struct SkeletonTrend: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.unspecced.defs#skeletonTrend"
        public let topic: String
        public let displayName: String
        public let link: String
        public let startedAt: ATProtocolDate
        public let postCount: Int
        public let status: String?
        public let category: String?
        public let dids: [DID]

        // Standard initializer
        public init(
            topic: String, displayName: String, link: String, startedAt: ATProtocolDate, postCount: Int, status: String?, category: String?, dids: [DID]
        ) {
            self.topic = topic
            self.displayName = displayName
            self.link = link
            self.startedAt = startedAt
            self.postCount = postCount
            self.status = status
            self.category = category
            self.dids = dids
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                topic = try container.decode(String.self, forKey: .topic)

            } catch {
                LogManager.logError("Decoding error for property 'topic': \(error)")
                throw error
            }
            do {
                displayName = try container.decode(String.self, forKey: .displayName)

            } catch {
                LogManager.logError("Decoding error for property 'displayName': \(error)")
                throw error
            }
            do {
                link = try container.decode(String.self, forKey: .link)

            } catch {
                LogManager.logError("Decoding error for property 'link': \(error)")
                throw error
            }
            do {
                startedAt = try container.decode(ATProtocolDate.self, forKey: .startedAt)

            } catch {
                LogManager.logError("Decoding error for property 'startedAt': \(error)")
                throw error
            }
            do {
                postCount = try container.decode(Int.self, forKey: .postCount)

            } catch {
                LogManager.logError("Decoding error for property 'postCount': \(error)")
                throw error
            }
            do {
                status = try container.decodeIfPresent(String.self, forKey: .status)

            } catch {
                LogManager.logError("Decoding error for property 'status': \(error)")
                throw error
            }
            do {
                category = try container.decodeIfPresent(String.self, forKey: .category)

            } catch {
                LogManager.logError("Decoding error for property 'category': \(error)")
                throw error
            }
            do {
                dids = try container.decode([DID].self, forKey: .dids)

            } catch {
                LogManager.logError("Decoding error for property 'dids': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(topic, forKey: .topic)

            try container.encode(displayName, forKey: .displayName)

            try container.encode(link, forKey: .link)

            try container.encode(startedAt, forKey: .startedAt)

            try container.encode(postCount, forKey: .postCount)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(status, forKey: .status)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(category, forKey: .category)

            try container.encode(dids, forKey: .dids)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(topic)
            hasher.combine(displayName)
            hasher.combine(link)
            hasher.combine(startedAt)
            hasher.combine(postCount)
            if let value = status {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = category {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(dids)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if topic != other.topic {
                return false
            }

            if displayName != other.displayName {
                return false
            }

            if link != other.link {
                return false
            }

            if startedAt != other.startedAt {
                return false
            }

            if postCount != other.postCount {
                return false
            }

            if status != other.status {
                return false
            }

            if category != other.category {
                return false
            }

            if dids != other.dids {
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

            let topicValue = try (topic as? DAGCBOREncodable)?.toCBORValue() ?? topic
            map = map.adding(key: "topic", value: topicValue)

            let displayNameValue = try (displayName as? DAGCBOREncodable)?.toCBORValue() ?? displayName
            map = map.adding(key: "displayName", value: displayNameValue)

            let linkValue = try (link as? DAGCBOREncodable)?.toCBORValue() ?? link
            map = map.adding(key: "link", value: linkValue)

            let startedAtValue = try (startedAt as? DAGCBOREncodable)?.toCBORValue() ?? startedAt
            map = map.adding(key: "startedAt", value: startedAtValue)

            let postCountValue = try (postCount as? DAGCBOREncodable)?.toCBORValue() ?? postCount
            map = map.adding(key: "postCount", value: postCountValue)

            if let value = status {
                // Encode optional property even if it's an empty array for CBOR

                let statusValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "status", value: statusValue)
            }

            if let value = category {
                // Encode optional property even if it's an empty array for CBOR

                let categoryValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "category", value: categoryValue)
            }

            let didsValue = try (dids as? DAGCBOREncodable)?.toCBORValue() ?? dids
            map = map.adding(key: "dids", value: didsValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case topic
            case displayName
            case link
            case startedAt
            case postCount
            case status
            case category
            case dids
        }
    }

    public struct TrendView: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.unspecced.defs#trendView"
        public let topic: String
        public let displayName: String
        public let link: String
        public let startedAt: ATProtocolDate
        public let postCount: Int
        public let status: String?
        public let category: String?
        public let actors: [AppBskyActorDefs.ProfileViewBasic]

        // Standard initializer
        public init(
            topic: String, displayName: String, link: String, startedAt: ATProtocolDate, postCount: Int, status: String?, category: String?, actors: [AppBskyActorDefs.ProfileViewBasic]
        ) {
            self.topic = topic
            self.displayName = displayName
            self.link = link
            self.startedAt = startedAt
            self.postCount = postCount
            self.status = status
            self.category = category
            self.actors = actors
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                topic = try container.decode(String.self, forKey: .topic)

            } catch {
                LogManager.logError("Decoding error for property 'topic': \(error)")
                throw error
            }
            do {
                displayName = try container.decode(String.self, forKey: .displayName)

            } catch {
                LogManager.logError("Decoding error for property 'displayName': \(error)")
                throw error
            }
            do {
                link = try container.decode(String.self, forKey: .link)

            } catch {
                LogManager.logError("Decoding error for property 'link': \(error)")
                throw error
            }
            do {
                startedAt = try container.decode(ATProtocolDate.self, forKey: .startedAt)

            } catch {
                LogManager.logError("Decoding error for property 'startedAt': \(error)")
                throw error
            }
            do {
                postCount = try container.decode(Int.self, forKey: .postCount)

            } catch {
                LogManager.logError("Decoding error for property 'postCount': \(error)")
                throw error
            }
            do {
                status = try container.decodeIfPresent(String.self, forKey: .status)

            } catch {
                LogManager.logError("Decoding error for property 'status': \(error)")
                throw error
            }
            do {
                category = try container.decodeIfPresent(String.self, forKey: .category)

            } catch {
                LogManager.logError("Decoding error for property 'category': \(error)")
                throw error
            }
            do {
                actors = try container.decode([AppBskyActorDefs.ProfileViewBasic].self, forKey: .actors)

            } catch {
                LogManager.logError("Decoding error for property 'actors': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(topic, forKey: .topic)

            try container.encode(displayName, forKey: .displayName)

            try container.encode(link, forKey: .link)

            try container.encode(startedAt, forKey: .startedAt)

            try container.encode(postCount, forKey: .postCount)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(status, forKey: .status)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(category, forKey: .category)

            try container.encode(actors, forKey: .actors)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(topic)
            hasher.combine(displayName)
            hasher.combine(link)
            hasher.combine(startedAt)
            hasher.combine(postCount)
            if let value = status {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = category {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(actors)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if topic != other.topic {
                return false
            }

            if displayName != other.displayName {
                return false
            }

            if link != other.link {
                return false
            }

            if startedAt != other.startedAt {
                return false
            }

            if postCount != other.postCount {
                return false
            }

            if status != other.status {
                return false
            }

            if category != other.category {
                return false
            }

            if actors != other.actors {
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

            let topicValue = try (topic as? DAGCBOREncodable)?.toCBORValue() ?? topic
            map = map.adding(key: "topic", value: topicValue)

            let displayNameValue = try (displayName as? DAGCBOREncodable)?.toCBORValue() ?? displayName
            map = map.adding(key: "displayName", value: displayNameValue)

            let linkValue = try (link as? DAGCBOREncodable)?.toCBORValue() ?? link
            map = map.adding(key: "link", value: linkValue)

            let startedAtValue = try (startedAt as? DAGCBOREncodable)?.toCBORValue() ?? startedAt
            map = map.adding(key: "startedAt", value: startedAtValue)

            let postCountValue = try (postCount as? DAGCBOREncodable)?.toCBORValue() ?? postCount
            map = map.adding(key: "postCount", value: postCountValue)

            if let value = status {
                // Encode optional property even if it's an empty array for CBOR

                let statusValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "status", value: statusValue)
            }

            if let value = category {
                // Encode optional property even if it's an empty array for CBOR

                let categoryValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "category", value: categoryValue)
            }

            let actorsValue = try (actors as? DAGCBOREncodable)?.toCBORValue() ?? actors
            map = map.adding(key: "actors", value: actorsValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case topic
            case displayName
            case link
            case startedAt
            case postCount
            case status
            case category
            case actors
        }
    }
}
