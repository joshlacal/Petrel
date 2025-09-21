import Foundation



// lexicon: 1, id: app.bsky.unspecced.defs


public struct AppBskyUnspeccedDefs { 

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
                
                self.uri = try container.decode(ATProtocolURI.self, forKey: .uri)
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'uri': \(error)")
                
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
            
            if self.uri != other.uri {
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
                
                self.did = try container.decode(DID.self, forKey: .did)
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'did': \(error)")
                
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
            
            if self.did != other.did {
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

            
            
            
            let didValue = try did.toCBORValue()
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
                
                self.uri = try container.decode(ATProtocolURI.self, forKey: .uri)
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'uri': \(error)")
                
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
            
            if self.uri != other.uri {
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
                
                self.topic = try container.decode(String.self, forKey: .topic)
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'topic': \(error)")
                
                throw error
            }
            do {
                
                self.displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'displayName': \(error)")
                
                throw error
            }
            do {
                
                self.description = try container.decodeIfPresent(String.self, forKey: .description)
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'description': \(error)")
                
                throw error
            }
            do {
                
                self.link = try container.decode(String.self, forKey: .link)
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'link': \(error)")
                
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
            
            if self.topic != other.topic {
                return false
            }
            
            
            if displayName != other.displayName {
                return false
            }
            
            
            if description != other.description {
                return false
            }
            
            
            if self.link != other.link {
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

            
            
            
            let topicValue = try topic.toCBORValue()
            map = map.adding(key: "topic", value: topicValue)
            
            
            
            if let value = displayName {
                // Encode optional property even if it's an empty array for CBOR
                
                let displayNameValue = try value.toCBORValue()
                map = map.adding(key: "displayName", value: displayNameValue)
            }
            
            
            
            if let value = description {
                // Encode optional property even if it's an empty array for CBOR
                
                let descriptionValue = try value.toCBORValue()
                map = map.adding(key: "description", value: descriptionValue)
            }
            
            
            
            
            let linkValue = try link.toCBORValue()
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
                
                self.topic = try container.decode(String.self, forKey: .topic)
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'topic': \(error)")
                
                throw error
            }
            do {
                
                self.displayName = try container.decode(String.self, forKey: .displayName)
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'displayName': \(error)")
                
                throw error
            }
            do {
                
                self.link = try container.decode(String.self, forKey: .link)
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'link': \(error)")
                
                throw error
            }
            do {
                
                self.startedAt = try container.decode(ATProtocolDate.self, forKey: .startedAt)
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'startedAt': \(error)")
                
                throw error
            }
            do {
                
                self.postCount = try container.decode(Int.self, forKey: .postCount)
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'postCount': \(error)")
                
                throw error
            }
            do {
                
                self.status = try container.decodeIfPresent(String.self, forKey: .status)
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'status': \(error)")
                
                throw error
            }
            do {
                
                self.category = try container.decodeIfPresent(String.self, forKey: .category)
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'category': \(error)")
                
                throw error
            }
            do {
                
                self.dids = try container.decode([DID].self, forKey: .dids)
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'dids': \(error)")
                
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
            
            if self.topic != other.topic {
                return false
            }
            
            
            if self.displayName != other.displayName {
                return false
            }
            
            
            if self.link != other.link {
                return false
            }
            
            
            if self.startedAt != other.startedAt {
                return false
            }
            
            
            if self.postCount != other.postCount {
                return false
            }
            
            
            if status != other.status {
                return false
            }
            
            
            if category != other.category {
                return false
            }
            
            
            if self.dids != other.dids {
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

            
            
            
            let topicValue = try topic.toCBORValue()
            map = map.adding(key: "topic", value: topicValue)
            
            
            
            
            let displayNameValue = try displayName.toCBORValue()
            map = map.adding(key: "displayName", value: displayNameValue)
            
            
            
            
            let linkValue = try link.toCBORValue()
            map = map.adding(key: "link", value: linkValue)
            
            
            
            
            let startedAtValue = try startedAt.toCBORValue()
            map = map.adding(key: "startedAt", value: startedAtValue)
            
            
            
            
            let postCountValue = try postCount.toCBORValue()
            map = map.adding(key: "postCount", value: postCountValue)
            
            
            
            if let value = status {
                // Encode optional property even if it's an empty array for CBOR
                
                let statusValue = try value.toCBORValue()
                map = map.adding(key: "status", value: statusValue)
            }
            
            
            
            if let value = category {
                // Encode optional property even if it's an empty array for CBOR
                
                let categoryValue = try value.toCBORValue()
                map = map.adding(key: "category", value: categoryValue)
            }
            
            
            
            
            let didsValue = try dids.toCBORValue()
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
                
                self.topic = try container.decode(String.self, forKey: .topic)
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'topic': \(error)")
                
                throw error
            }
            do {
                
                self.displayName = try container.decode(String.self, forKey: .displayName)
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'displayName': \(error)")
                
                throw error
            }
            do {
                
                self.link = try container.decode(String.self, forKey: .link)
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'link': \(error)")
                
                throw error
            }
            do {
                
                self.startedAt = try container.decode(ATProtocolDate.self, forKey: .startedAt)
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'startedAt': \(error)")
                
                throw error
            }
            do {
                
                self.postCount = try container.decode(Int.self, forKey: .postCount)
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'postCount': \(error)")
                
                throw error
            }
            do {
                
                self.status = try container.decodeIfPresent(String.self, forKey: .status)
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'status': \(error)")
                
                throw error
            }
            do {
                
                self.category = try container.decodeIfPresent(String.self, forKey: .category)
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'category': \(error)")
                
                throw error
            }
            do {
                
                self.actors = try container.decode([AppBskyActorDefs.ProfileViewBasic].self, forKey: .actors)
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'actors': \(error)")
                
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
            
            if self.topic != other.topic {
                return false
            }
            
            
            if self.displayName != other.displayName {
                return false
            }
            
            
            if self.link != other.link {
                return false
            }
            
            
            if self.startedAt != other.startedAt {
                return false
            }
            
            
            if self.postCount != other.postCount {
                return false
            }
            
            
            if status != other.status {
                return false
            }
            
            
            if category != other.category {
                return false
            }
            
            
            if self.actors != other.actors {
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

            
            
            
            let topicValue = try topic.toCBORValue()
            map = map.adding(key: "topic", value: topicValue)
            
            
            
            
            let displayNameValue = try displayName.toCBORValue()
            map = map.adding(key: "displayName", value: displayNameValue)
            
            
            
            
            let linkValue = try link.toCBORValue()
            map = map.adding(key: "link", value: linkValue)
            
            
            
            
            let startedAtValue = try startedAt.toCBORValue()
            map = map.adding(key: "startedAt", value: startedAtValue)
            
            
            
            
            let postCountValue = try postCount.toCBORValue()
            map = map.adding(key: "postCount", value: postCountValue)
            
            
            
            if let value = status {
                // Encode optional property even if it's an empty array for CBOR
                
                let statusValue = try value.toCBORValue()
                map = map.adding(key: "status", value: statusValue)
            }
            
            
            
            if let value = category {
                // Encode optional property even if it's an empty array for CBOR
                
                let categoryValue = try value.toCBORValue()
                map = map.adding(key: "category", value: categoryValue)
            }
            
            
            
            
            let actorsValue = try actors.toCBORValue()
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
        
public struct ThreadItemPost: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.unspecced.defs#threadItemPost"
            public let post: AppBskyFeedDefs.PostView
            public let moreParents: Bool
            public let moreReplies: Int
            public let opThread: Bool
            public let hiddenByThreadgate: Bool
            public let mutedByViewer: Bool

        // Standard initializer
        public init(
            post: AppBskyFeedDefs.PostView, moreParents: Bool, moreReplies: Int, opThread: Bool, hiddenByThreadgate: Bool, mutedByViewer: Bool
        ) {
            
            self.post = post
            self.moreParents = moreParents
            self.moreReplies = moreReplies
            self.opThread = opThread
            self.hiddenByThreadgate = hiddenByThreadgate
            self.mutedByViewer = mutedByViewer
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.post = try container.decode(AppBskyFeedDefs.PostView.self, forKey: .post)
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'post': \(error)")
                
                throw error
            }
            do {
                
                self.moreParents = try container.decode(Bool.self, forKey: .moreParents)
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'moreParents': \(error)")
                
                throw error
            }
            do {
                
                self.moreReplies = try container.decode(Int.self, forKey: .moreReplies)
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'moreReplies': \(error)")
                
                throw error
            }
            do {
                
                self.opThread = try container.decode(Bool.self, forKey: .opThread)
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'opThread': \(error)")
                
                throw error
            }
            do {
                
                self.hiddenByThreadgate = try container.decode(Bool.self, forKey: .hiddenByThreadgate)
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'hiddenByThreadgate': \(error)")
                
                throw error
            }
            do {
                
                self.mutedByViewer = try container.decode(Bool.self, forKey: .mutedByViewer)
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'mutedByViewer': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(post, forKey: .post)
            
            
            try container.encode(moreParents, forKey: .moreParents)
            
            
            try container.encode(moreReplies, forKey: .moreReplies)
            
            
            try container.encode(opThread, forKey: .opThread)
            
            
            try container.encode(hiddenByThreadgate, forKey: .hiddenByThreadgate)
            
            
            try container.encode(mutedByViewer, forKey: .mutedByViewer)
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(post)
            hasher.combine(moreParents)
            hasher.combine(moreReplies)
            hasher.combine(opThread)
            hasher.combine(hiddenByThreadgate)
            hasher.combine(mutedByViewer)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            if self.post != other.post {
                return false
            }
            
            
            if self.moreParents != other.moreParents {
                return false
            }
            
            
            if self.moreReplies != other.moreReplies {
                return false
            }
            
            
            if self.opThread != other.opThread {
                return false
            }
            
            
            if self.hiddenByThreadgate != other.hiddenByThreadgate {
                return false
            }
            
            
            if self.mutedByViewer != other.mutedByViewer {
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

            
            
            
            let postValue = try post.toCBORValue()
            map = map.adding(key: "post", value: postValue)
            
            
            
            
            let moreParentsValue = try moreParents.toCBORValue()
            map = map.adding(key: "moreParents", value: moreParentsValue)
            
            
            
            
            let moreRepliesValue = try moreReplies.toCBORValue()
            map = map.adding(key: "moreReplies", value: moreRepliesValue)
            
            
            
            
            let opThreadValue = try opThread.toCBORValue()
            map = map.adding(key: "opThread", value: opThreadValue)
            
            
            
            
            let hiddenByThreadgateValue = try hiddenByThreadgate.toCBORValue()
            map = map.adding(key: "hiddenByThreadgate", value: hiddenByThreadgateValue)
            
            
            
            
            let mutedByViewerValue = try mutedByViewer.toCBORValue()
            map = map.adding(key: "mutedByViewer", value: mutedByViewerValue)
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case post
            case moreParents
            case moreReplies
            case opThread
            case hiddenByThreadgate
            case mutedByViewer
        }
    }
        
public struct ThreadItemNoUnauthenticated: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.unspecced.defs#threadItemNoUnauthenticated"

        // Standard initializer
        public init(
            
        ) {
            
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let _ = decoder  // Acknowledge parameter for empty struct
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
        }

        public func hash(into hasher: inout Hasher) {
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            return other is Self  // For empty structs, just check the type
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
        }
    }
        
public struct ThreadItemNotFound: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.unspecced.defs#threadItemNotFound"

        // Standard initializer
        public init(
            
        ) {
            
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let _ = decoder  // Acknowledge parameter for empty struct
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
        }

        public func hash(into hasher: inout Hasher) {
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            return other is Self  // For empty structs, just check the type
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
        }
    }
        
public struct ThreadItemBlocked: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.unspecced.defs#threadItemBlocked"
            public let author: AppBskyFeedDefs.BlockedAuthor

        // Standard initializer
        public init(
            author: AppBskyFeedDefs.BlockedAuthor
        ) {
            
            self.author = author
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.author = try container.decode(AppBskyFeedDefs.BlockedAuthor.self, forKey: .author)
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'author': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(author, forKey: .author)
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(author)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            if self.author != other.author {
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

            
            
            
            let authorValue = try author.toCBORValue()
            map = map.adding(key: "author", value: authorValue)
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case author
        }
    }
        
public struct AgeAssuranceState: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.unspecced.defs#ageAssuranceState"
            public let lastInitiatedAt: ATProtocolDate?
            public let status: String

        // Standard initializer
        public init(
            lastInitiatedAt: ATProtocolDate?, status: String
        ) {
            
            self.lastInitiatedAt = lastInitiatedAt
            self.status = status
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.lastInitiatedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .lastInitiatedAt)
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'lastInitiatedAt': \(error)")
                
                throw error
            }
            do {
                
                self.status = try container.decode(String.self, forKey: .status)
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'status': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(lastInitiatedAt, forKey: .lastInitiatedAt)
            
            
            try container.encode(status, forKey: .status)
            
        }

        public func hash(into hasher: inout Hasher) {
            if let value = lastInitiatedAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(status)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            if lastInitiatedAt != other.lastInitiatedAt {
                return false
            }
            
            
            if self.status != other.status {
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

            
            
            if let value = lastInitiatedAt {
                // Encode optional property even if it's an empty array for CBOR
                
                let lastInitiatedAtValue = try value.toCBORValue()
                map = map.adding(key: "lastInitiatedAt", value: lastInitiatedAtValue)
            }
            
            
            
            
            let statusValue = try status.toCBORValue()
            map = map.adding(key: "status", value: statusValue)
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case lastInitiatedAt
            case status
        }
    }
        
public struct AgeAssuranceEvent: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.unspecced.defs#ageAssuranceEvent"
            public let createdAt: ATProtocolDate
            public let status: String
            public let attemptId: String
            public let email: String?
            public let initIp: String?
            public let initUa: String?
            public let completeIp: String?
            public let completeUa: String?

        // Standard initializer
        public init(
            createdAt: ATProtocolDate, status: String, attemptId: String, email: String?, initIp: String?, initUa: String?, completeIp: String?, completeUa: String?
        ) {
            
            self.createdAt = createdAt
            self.status = status
            self.attemptId = attemptId
            self.email = email
            self.initIp = initIp
            self.initUa = initUa
            self.completeIp = completeIp
            self.completeUa = completeUa
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'createdAt': \(error)")
                
                throw error
            }
            do {
                
                self.status = try container.decode(String.self, forKey: .status)
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'status': \(error)")
                
                throw error
            }
            do {
                
                self.attemptId = try container.decode(String.self, forKey: .attemptId)
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'attemptId': \(error)")
                
                throw error
            }
            do {
                
                self.email = try container.decodeIfPresent(String.self, forKey: .email)
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'email': \(error)")
                
                throw error
            }
            do {
                
                self.initIp = try container.decodeIfPresent(String.self, forKey: .initIp)
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'initIp': \(error)")
                
                throw error
            }
            do {
                
                self.initUa = try container.decodeIfPresent(String.self, forKey: .initUa)
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'initUa': \(error)")
                
                throw error
            }
            do {
                
                self.completeIp = try container.decodeIfPresent(String.self, forKey: .completeIp)
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'completeIp': \(error)")
                
                throw error
            }
            do {
                
                self.completeUa = try container.decodeIfPresent(String.self, forKey: .completeUa)
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'completeUa': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(createdAt, forKey: .createdAt)
            
            
            try container.encode(status, forKey: .status)
            
            
            try container.encode(attemptId, forKey: .attemptId)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(email, forKey: .email)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(initIp, forKey: .initIp)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(initUa, forKey: .initUa)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(completeIp, forKey: .completeIp)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(completeUa, forKey: .completeUa)
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(createdAt)
            hasher.combine(status)
            hasher.combine(attemptId)
            if let value = email {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = initIp {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = initUa {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = completeIp {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = completeUa {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            if self.createdAt != other.createdAt {
                return false
            }
            
            
            if self.status != other.status {
                return false
            }
            
            
            if self.attemptId != other.attemptId {
                return false
            }
            
            
            if email != other.email {
                return false
            }
            
            
            if initIp != other.initIp {
                return false
            }
            
            
            if initUa != other.initUa {
                return false
            }
            
            
            if completeIp != other.completeIp {
                return false
            }
            
            
            if completeUa != other.completeUa {
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

            
            
            
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            
            
            
            
            let statusValue = try status.toCBORValue()
            map = map.adding(key: "status", value: statusValue)
            
            
            
            
            let attemptIdValue = try attemptId.toCBORValue()
            map = map.adding(key: "attemptId", value: attemptIdValue)
            
            
            
            if let value = email {
                // Encode optional property even if it's an empty array for CBOR
                
                let emailValue = try value.toCBORValue()
                map = map.adding(key: "email", value: emailValue)
            }
            
            
            
            if let value = initIp {
                // Encode optional property even if it's an empty array for CBOR
                
                let initIpValue = try value.toCBORValue()
                map = map.adding(key: "initIp", value: initIpValue)
            }
            
            
            
            if let value = initUa {
                // Encode optional property even if it's an empty array for CBOR
                
                let initUaValue = try value.toCBORValue()
                map = map.adding(key: "initUa", value: initUaValue)
            }
            
            
            
            if let value = completeIp {
                // Encode optional property even if it's an empty array for CBOR
                
                let completeIpValue = try value.toCBORValue()
                map = map.adding(key: "completeIp", value: completeIpValue)
            }
            
            
            
            if let value = completeUa {
                // Encode optional property even if it's an empty array for CBOR
                
                let completeUaValue = try value.toCBORValue()
                map = map.adding(key: "completeUa", value: completeUaValue)
            }
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case createdAt
            case status
            case attemptId
            case email
            case initIp
            case initUa
            case completeIp
            case completeUa
        }
    }



}


                           
