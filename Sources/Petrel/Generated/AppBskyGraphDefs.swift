import Foundation



// lexicon: 1, id: app.bsky.graph.defs


public struct AppBskyGraphDefs { 

    public static let typeIdentifier = "app.bsky.graph.defs"
        
public struct ListViewBasic: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.graph.defs#listViewBasic"
            public let uri: ATProtocolURI
            public let cid: CID
            public let name: String
            public let purpose: ListPurpose
            public let avatar: URI?
            public let listItemCount: Int?
            public let labels: [ComAtprotoLabelDefs.Label]?
            public let viewer: ListViewerState?
            public let indexedAt: ATProtocolDate?

        // Standard initializer
        public init(
            uri: ATProtocolURI, cid: CID, name: String, purpose: ListPurpose, avatar: URI?, listItemCount: Int?, labels: [ComAtprotoLabelDefs.Label]?, viewer: ListViewerState?, indexedAt: ATProtocolDate?
        ) {
            
            self.uri = uri
            self.cid = cid
            self.name = name
            self.purpose = purpose
            self.avatar = avatar
            self.listItemCount = listItemCount
            self.labels = labels
            self.viewer = viewer
            self.indexedAt = indexedAt
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
            do {
                
                
                self.cid = try container.decode(CID.self, forKey: .cid)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'cid': \(error)")
                
                throw error
            }
            do {
                
                
                self.name = try container.decode(String.self, forKey: .name)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'name': \(error)")
                
                throw error
            }
            do {
                
                
                self.purpose = try container.decode(ListPurpose.self, forKey: .purpose)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'purpose': \(error)")
                
                throw error
            }
            do {
                
                
                self.avatar = try container.decodeIfPresent(URI.self, forKey: .avatar)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'avatar': \(error)")
                
                throw error
            }
            do {
                
                
                self.listItemCount = try container.decodeIfPresent(Int.self, forKey: .listItemCount)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'listItemCount': \(error)")
                
                throw error
            }
            do {
                
                
                self.labels = try container.decodeIfPresent([ComAtprotoLabelDefs.Label].self, forKey: .labels)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'labels': \(error)")
                
                throw error
            }
            do {
                
                
                self.viewer = try container.decodeIfPresent(ListViewerState.self, forKey: .viewer)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'viewer': \(error)")
                
                throw error
            }
            do {
                
                
                self.indexedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .indexedAt)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'indexedAt': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(uri, forKey: .uri)
            
            
            
            
            try container.encode(cid, forKey: .cid)
            
            
            
            
            try container.encode(name, forKey: .name)
            
            
            
            
            try container.encode(purpose, forKey: .purpose)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(avatar, forKey: .avatar)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(listItemCount, forKey: .listItemCount)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(labels, forKey: .labels)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(viewer, forKey: .viewer)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(indexedAt, forKey: .indexedAt)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
            hasher.combine(cid)
            hasher.combine(name)
            hasher.combine(purpose)
            if let value = avatar {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = listItemCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = labels {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = viewer {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = indexedAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.uri != other.uri {
                return false
            }
            
            
            
            
            if self.cid != other.cid {
                return false
            }
            
            
            
            
            if self.name != other.name {
                return false
            }
            
            
            
            
            if self.purpose != other.purpose {
                return false
            }
            
            
            
            
            if avatar != other.avatar {
                return false
            }
            
            
            
            
            if listItemCount != other.listItemCount {
                return false
            }
            
            
            
            
            if labels != other.labels {
                return false
            }
            
            
            
            
            if viewer != other.viewer {
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
            
            
            
            
            
            
            let nameValue = try name.toCBORValue()
            map = map.adding(key: "name", value: nameValue)
            
            
            
            
            
            
            let purposeValue = try purpose.toCBORValue()
            map = map.adding(key: "purpose", value: purposeValue)
            
            
            
            
            
            if let value = avatar {
                // Encode optional property even if it's an empty array for CBOR
                
                let avatarValue = try value.toCBORValue()
                map = map.adding(key: "avatar", value: avatarValue)
            }
            
            
            
            
            
            if let value = listItemCount {
                // Encode optional property even if it's an empty array for CBOR
                
                let listItemCountValue = try value.toCBORValue()
                map = map.adding(key: "listItemCount", value: listItemCountValue)
            }
            
            
            
            
            
            if let value = labels {
                // Encode optional property even if it's an empty array for CBOR
                
                let labelsValue = try value.toCBORValue()
                map = map.adding(key: "labels", value: labelsValue)
            }
            
            
            
            
            
            if let value = viewer {
                // Encode optional property even if it's an empty array for CBOR
                
                let viewerValue = try value.toCBORValue()
                map = map.adding(key: "viewer", value: viewerValue)
            }
            
            
            
            
            
            if let value = indexedAt {
                // Encode optional property even if it's an empty array for CBOR
                
                let indexedAtValue = try value.toCBORValue()
                map = map.adding(key: "indexedAt", value: indexedAtValue)
            }
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
            case cid
            case name
            case purpose
            case avatar
            case listItemCount
            case labels
            case viewer
            case indexedAt
        }
    }
        
public struct ListView: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.graph.defs#listView"
            public let uri: ATProtocolURI
            public let cid: CID
            public let creator: AppBskyActorDefs.ProfileView
            public let name: String
            public let purpose: ListPurpose
            public let description: String?
            public let descriptionFacets: [AppBskyRichtextFacet]?
            public let avatar: URI?
            public let listItemCount: Int?
            public let labels: [ComAtprotoLabelDefs.Label]?
            public let viewer: ListViewerState?
            public let indexedAt: ATProtocolDate

        // Standard initializer
        public init(
            uri: ATProtocolURI, cid: CID, creator: AppBskyActorDefs.ProfileView, name: String, purpose: ListPurpose, description: String?, descriptionFacets: [AppBskyRichtextFacet]?, avatar: URI?, listItemCount: Int?, labels: [ComAtprotoLabelDefs.Label]?, viewer: ListViewerState?, indexedAt: ATProtocolDate
        ) {
            
            self.uri = uri
            self.cid = cid
            self.creator = creator
            self.name = name
            self.purpose = purpose
            self.description = description
            self.descriptionFacets = descriptionFacets
            self.avatar = avatar
            self.listItemCount = listItemCount
            self.labels = labels
            self.viewer = viewer
            self.indexedAt = indexedAt
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
            do {
                
                
                self.cid = try container.decode(CID.self, forKey: .cid)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'cid': \(error)")
                
                throw error
            }
            do {
                
                
                self.creator = try container.decode(AppBskyActorDefs.ProfileView.self, forKey: .creator)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'creator': \(error)")
                
                throw error
            }
            do {
                
                
                self.name = try container.decode(String.self, forKey: .name)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'name': \(error)")
                
                throw error
            }
            do {
                
                
                self.purpose = try container.decode(ListPurpose.self, forKey: .purpose)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'purpose': \(error)")
                
                throw error
            }
            do {
                
                
                self.description = try container.decodeIfPresent(String.self, forKey: .description)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'description': \(error)")
                
                throw error
            }
            do {
                
                
                self.descriptionFacets = try container.decodeIfPresent([AppBskyRichtextFacet].self, forKey: .descriptionFacets)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'descriptionFacets': \(error)")
                
                throw error
            }
            do {
                
                
                self.avatar = try container.decodeIfPresent(URI.self, forKey: .avatar)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'avatar': \(error)")
                
                throw error
            }
            do {
                
                
                self.listItemCount = try container.decodeIfPresent(Int.self, forKey: .listItemCount)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'listItemCount': \(error)")
                
                throw error
            }
            do {
                
                
                self.labels = try container.decodeIfPresent([ComAtprotoLabelDefs.Label].self, forKey: .labels)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'labels': \(error)")
                
                throw error
            }
            do {
                
                
                self.viewer = try container.decodeIfPresent(ListViewerState.self, forKey: .viewer)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'viewer': \(error)")
                
                throw error
            }
            do {
                
                
                self.indexedAt = try container.decode(ATProtocolDate.self, forKey: .indexedAt)
                
                
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
            
            
            
            
            try container.encode(creator, forKey: .creator)
            
            
            
            
            try container.encode(name, forKey: .name)
            
            
            
            
            try container.encode(purpose, forKey: .purpose)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(description, forKey: .description)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(descriptionFacets, forKey: .descriptionFacets)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(avatar, forKey: .avatar)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(listItemCount, forKey: .listItemCount)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(labels, forKey: .labels)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(viewer, forKey: .viewer)
            
            
            
            
            try container.encode(indexedAt, forKey: .indexedAt)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
            hasher.combine(cid)
            hasher.combine(creator)
            hasher.combine(name)
            hasher.combine(purpose)
            if let value = description {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = descriptionFacets {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = avatar {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = listItemCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = labels {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = viewer {
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
            
            
            
            
            if self.creator != other.creator {
                return false
            }
            
            
            
            
            if self.name != other.name {
                return false
            }
            
            
            
            
            if self.purpose != other.purpose {
                return false
            }
            
            
            
            
            if description != other.description {
                return false
            }
            
            
            
            
            if descriptionFacets != other.descriptionFacets {
                return false
            }
            
            
            
            
            if avatar != other.avatar {
                return false
            }
            
            
            
            
            if listItemCount != other.listItemCount {
                return false
            }
            
            
            
            
            if labels != other.labels {
                return false
            }
            
            
            
            
            if viewer != other.viewer {
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let uriValue = try uri.toCBORValue()
            map = map.adding(key: "uri", value: uriValue)
            
            
            
            
            
            
            let cidValue = try cid.toCBORValue()
            map = map.adding(key: "cid", value: cidValue)
            
            
            
            
            
            
            let creatorValue = try creator.toCBORValue()
            map = map.adding(key: "creator", value: creatorValue)
            
            
            
            
            
            
            let nameValue = try name.toCBORValue()
            map = map.adding(key: "name", value: nameValue)
            
            
            
            
            
            
            let purposeValue = try purpose.toCBORValue()
            map = map.adding(key: "purpose", value: purposeValue)
            
            
            
            
            
            if let value = description {
                // Encode optional property even if it's an empty array for CBOR
                
                let descriptionValue = try value.toCBORValue()
                map = map.adding(key: "description", value: descriptionValue)
            }
            
            
            
            
            
            if let value = descriptionFacets {
                // Encode optional property even if it's an empty array for CBOR
                
                let descriptionFacetsValue = try value.toCBORValue()
                map = map.adding(key: "descriptionFacets", value: descriptionFacetsValue)
            }
            
            
            
            
            
            if let value = avatar {
                // Encode optional property even if it's an empty array for CBOR
                
                let avatarValue = try value.toCBORValue()
                map = map.adding(key: "avatar", value: avatarValue)
            }
            
            
            
            
            
            if let value = listItemCount {
                // Encode optional property even if it's an empty array for CBOR
                
                let listItemCountValue = try value.toCBORValue()
                map = map.adding(key: "listItemCount", value: listItemCountValue)
            }
            
            
            
            
            
            if let value = labels {
                // Encode optional property even if it's an empty array for CBOR
                
                let labelsValue = try value.toCBORValue()
                map = map.adding(key: "labels", value: labelsValue)
            }
            
            
            
            
            
            if let value = viewer {
                // Encode optional property even if it's an empty array for CBOR
                
                let viewerValue = try value.toCBORValue()
                map = map.adding(key: "viewer", value: viewerValue)
            }
            
            
            
            
            
            
            let indexedAtValue = try indexedAt.toCBORValue()
            map = map.adding(key: "indexedAt", value: indexedAtValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
            case cid
            case creator
            case name
            case purpose
            case description
            case descriptionFacets
            case avatar
            case listItemCount
            case labels
            case viewer
            case indexedAt
        }
    }
        
public struct ListItemView: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.graph.defs#listItemView"
            public let uri: ATProtocolURI
            public let subject: AppBskyActorDefs.ProfileView

        // Standard initializer
        public init(
            uri: ATProtocolURI, subject: AppBskyActorDefs.ProfileView
        ) {
            
            self.uri = uri
            self.subject = subject
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
            do {
                
                
                self.subject = try container.decode(AppBskyActorDefs.ProfileView.self, forKey: .subject)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'subject': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(uri, forKey: .uri)
            
            
            
            
            try container.encode(subject, forKey: .subject)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
            hasher.combine(subject)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.uri != other.uri {
                return false
            }
            
            
            
            
            if self.subject != other.subject {
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
            
            
            
            
            
            
            let subjectValue = try subject.toCBORValue()
            map = map.adding(key: "subject", value: subjectValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
            case subject
        }
    }
        
public struct StarterPackView: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.graph.defs#starterPackView"
            public let uri: ATProtocolURI
            public let cid: CID
            public let record: ATProtocolValueContainer
            public let creator: AppBskyActorDefs.ProfileViewBasic
            public let list: ListViewBasic?
            public let listItemsSample: [ListItemView]?
            public let feeds: [AppBskyFeedDefs.GeneratorView]?
            public let joinedWeekCount: Int?
            public let joinedAllTimeCount: Int?
            public let labels: [ComAtprotoLabelDefs.Label]?
            public let indexedAt: ATProtocolDate

        // Standard initializer
        public init(
            uri: ATProtocolURI, cid: CID, record: ATProtocolValueContainer, creator: AppBskyActorDefs.ProfileViewBasic, list: ListViewBasic?, listItemsSample: [ListItemView]?, feeds: [AppBskyFeedDefs.GeneratorView]?, joinedWeekCount: Int?, joinedAllTimeCount: Int?, labels: [ComAtprotoLabelDefs.Label]?, indexedAt: ATProtocolDate
        ) {
            
            self.uri = uri
            self.cid = cid
            self.record = record
            self.creator = creator
            self.list = list
            self.listItemsSample = listItemsSample
            self.feeds = feeds
            self.joinedWeekCount = joinedWeekCount
            self.joinedAllTimeCount = joinedAllTimeCount
            self.labels = labels
            self.indexedAt = indexedAt
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
            do {
                
                
                self.cid = try container.decode(CID.self, forKey: .cid)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'cid': \(error)")
                
                throw error
            }
            do {
                
                
                self.record = try container.decode(ATProtocolValueContainer.self, forKey: .record)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'record': \(error)")
                
                throw error
            }
            do {
                
                
                self.creator = try container.decode(AppBskyActorDefs.ProfileViewBasic.self, forKey: .creator)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'creator': \(error)")
                
                throw error
            }
            do {
                
                
                self.list = try container.decodeIfPresent(ListViewBasic.self, forKey: .list)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'list': \(error)")
                
                throw error
            }
            do {
                
                
                self.listItemsSample = try container.decodeIfPresent([ListItemView].self, forKey: .listItemsSample)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'listItemsSample': \(error)")
                
                throw error
            }
            do {
                
                
                self.feeds = try container.decodeIfPresent([AppBskyFeedDefs.GeneratorView].self, forKey: .feeds)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'feeds': \(error)")
                
                throw error
            }
            do {
                
                
                self.joinedWeekCount = try container.decodeIfPresent(Int.self, forKey: .joinedWeekCount)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'joinedWeekCount': \(error)")
                
                throw error
            }
            do {
                
                
                self.joinedAllTimeCount = try container.decodeIfPresent(Int.self, forKey: .joinedAllTimeCount)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'joinedAllTimeCount': \(error)")
                
                throw error
            }
            do {
                
                
                self.labels = try container.decodeIfPresent([ComAtprotoLabelDefs.Label].self, forKey: .labels)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'labels': \(error)")
                
                throw error
            }
            do {
                
                
                self.indexedAt = try container.decode(ATProtocolDate.self, forKey: .indexedAt)
                
                
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
            
            
            
            
            try container.encode(record, forKey: .record)
            
            
            
            
            try container.encode(creator, forKey: .creator)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(list, forKey: .list)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(listItemsSample, forKey: .listItemsSample)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(feeds, forKey: .feeds)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(joinedWeekCount, forKey: .joinedWeekCount)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(joinedAllTimeCount, forKey: .joinedAllTimeCount)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(labels, forKey: .labels)
            
            
            
            
            try container.encode(indexedAt, forKey: .indexedAt)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
            hasher.combine(cid)
            hasher.combine(record)
            hasher.combine(creator)
            if let value = list {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = listItemsSample {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = feeds {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = joinedWeekCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = joinedAllTimeCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = labels {
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
            
            
            
            
            if self.record != other.record {
                return false
            }
            
            
            
            
            if self.creator != other.creator {
                return false
            }
            
            
            
            
            if list != other.list {
                return false
            }
            
            
            
            
            if listItemsSample != other.listItemsSample {
                return false
            }
            
            
            
            
            if feeds != other.feeds {
                return false
            }
            
            
            
            
            if joinedWeekCount != other.joinedWeekCount {
                return false
            }
            
            
            
            
            if joinedAllTimeCount != other.joinedAllTimeCount {
                return false
            }
            
            
            
            
            if labels != other.labels {
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let uriValue = try uri.toCBORValue()
            map = map.adding(key: "uri", value: uriValue)
            
            
            
            
            
            
            let cidValue = try cid.toCBORValue()
            map = map.adding(key: "cid", value: cidValue)
            
            
            
            
            
            
            let recordValue = try record.toCBORValue()
            map = map.adding(key: "record", value: recordValue)
            
            
            
            
            
            
            let creatorValue = try creator.toCBORValue()
            map = map.adding(key: "creator", value: creatorValue)
            
            
            
            
            
            if let value = list {
                // Encode optional property even if it's an empty array for CBOR
                
                let listValue = try value.toCBORValue()
                map = map.adding(key: "list", value: listValue)
            }
            
            
            
            
            
            if let value = listItemsSample {
                // Encode optional property even if it's an empty array for CBOR
                
                let listItemsSampleValue = try value.toCBORValue()
                map = map.adding(key: "listItemsSample", value: listItemsSampleValue)
            }
            
            
            
            
            
            if let value = feeds {
                // Encode optional property even if it's an empty array for CBOR
                
                let feedsValue = try value.toCBORValue()
                map = map.adding(key: "feeds", value: feedsValue)
            }
            
            
            
            
            
            if let value = joinedWeekCount {
                // Encode optional property even if it's an empty array for CBOR
                
                let joinedWeekCountValue = try value.toCBORValue()
                map = map.adding(key: "joinedWeekCount", value: joinedWeekCountValue)
            }
            
            
            
            
            
            if let value = joinedAllTimeCount {
                // Encode optional property even if it's an empty array for CBOR
                
                let joinedAllTimeCountValue = try value.toCBORValue()
                map = map.adding(key: "joinedAllTimeCount", value: joinedAllTimeCountValue)
            }
            
            
            
            
            
            if let value = labels {
                // Encode optional property even if it's an empty array for CBOR
                
                let labelsValue = try value.toCBORValue()
                map = map.adding(key: "labels", value: labelsValue)
            }
            
            
            
            
            
            
            let indexedAtValue = try indexedAt.toCBORValue()
            map = map.adding(key: "indexedAt", value: indexedAtValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
            case cid
            case record
            case creator
            case list
            case listItemsSample
            case feeds
            case joinedWeekCount
            case joinedAllTimeCount
            case labels
            case indexedAt
        }
    }
        
public struct StarterPackViewBasic: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.graph.defs#starterPackViewBasic"
            public let uri: ATProtocolURI
            public let cid: CID
            public let record: ATProtocolValueContainer
            public let creator: AppBskyActorDefs.ProfileViewBasic
            public let listItemCount: Int?
            public let joinedWeekCount: Int?
            public let joinedAllTimeCount: Int?
            public let labels: [ComAtprotoLabelDefs.Label]?
            public let indexedAt: ATProtocolDate

        // Standard initializer
        public init(
            uri: ATProtocolURI, cid: CID, record: ATProtocolValueContainer, creator: AppBskyActorDefs.ProfileViewBasic, listItemCount: Int?, joinedWeekCount: Int?, joinedAllTimeCount: Int?, labels: [ComAtprotoLabelDefs.Label]?, indexedAt: ATProtocolDate
        ) {
            
            self.uri = uri
            self.cid = cid
            self.record = record
            self.creator = creator
            self.listItemCount = listItemCount
            self.joinedWeekCount = joinedWeekCount
            self.joinedAllTimeCount = joinedAllTimeCount
            self.labels = labels
            self.indexedAt = indexedAt
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
            do {
                
                
                self.cid = try container.decode(CID.self, forKey: .cid)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'cid': \(error)")
                
                throw error
            }
            do {
                
                
                self.record = try container.decode(ATProtocolValueContainer.self, forKey: .record)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'record': \(error)")
                
                throw error
            }
            do {
                
                
                self.creator = try container.decode(AppBskyActorDefs.ProfileViewBasic.self, forKey: .creator)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'creator': \(error)")
                
                throw error
            }
            do {
                
                
                self.listItemCount = try container.decodeIfPresent(Int.self, forKey: .listItemCount)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'listItemCount': \(error)")
                
                throw error
            }
            do {
                
                
                self.joinedWeekCount = try container.decodeIfPresent(Int.self, forKey: .joinedWeekCount)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'joinedWeekCount': \(error)")
                
                throw error
            }
            do {
                
                
                self.joinedAllTimeCount = try container.decodeIfPresent(Int.self, forKey: .joinedAllTimeCount)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'joinedAllTimeCount': \(error)")
                
                throw error
            }
            do {
                
                
                self.labels = try container.decodeIfPresent([ComAtprotoLabelDefs.Label].self, forKey: .labels)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'labels': \(error)")
                
                throw error
            }
            do {
                
                
                self.indexedAt = try container.decode(ATProtocolDate.self, forKey: .indexedAt)
                
                
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
            
            
            
            
            try container.encode(record, forKey: .record)
            
            
            
            
            try container.encode(creator, forKey: .creator)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(listItemCount, forKey: .listItemCount)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(joinedWeekCount, forKey: .joinedWeekCount)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(joinedAllTimeCount, forKey: .joinedAllTimeCount)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(labels, forKey: .labels)
            
            
            
            
            try container.encode(indexedAt, forKey: .indexedAt)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
            hasher.combine(cid)
            hasher.combine(record)
            hasher.combine(creator)
            if let value = listItemCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = joinedWeekCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = joinedAllTimeCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = labels {
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
            
            
            
            
            if self.record != other.record {
                return false
            }
            
            
            
            
            if self.creator != other.creator {
                return false
            }
            
            
            
            
            if listItemCount != other.listItemCount {
                return false
            }
            
            
            
            
            if joinedWeekCount != other.joinedWeekCount {
                return false
            }
            
            
            
            
            if joinedAllTimeCount != other.joinedAllTimeCount {
                return false
            }
            
            
            
            
            if labels != other.labels {
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let uriValue = try uri.toCBORValue()
            map = map.adding(key: "uri", value: uriValue)
            
            
            
            
            
            
            let cidValue = try cid.toCBORValue()
            map = map.adding(key: "cid", value: cidValue)
            
            
            
            
            
            
            let recordValue = try record.toCBORValue()
            map = map.adding(key: "record", value: recordValue)
            
            
            
            
            
            
            let creatorValue = try creator.toCBORValue()
            map = map.adding(key: "creator", value: creatorValue)
            
            
            
            
            
            if let value = listItemCount {
                // Encode optional property even if it's an empty array for CBOR
                
                let listItemCountValue = try value.toCBORValue()
                map = map.adding(key: "listItemCount", value: listItemCountValue)
            }
            
            
            
            
            
            if let value = joinedWeekCount {
                // Encode optional property even if it's an empty array for CBOR
                
                let joinedWeekCountValue = try value.toCBORValue()
                map = map.adding(key: "joinedWeekCount", value: joinedWeekCountValue)
            }
            
            
            
            
            
            if let value = joinedAllTimeCount {
                // Encode optional property even if it's an empty array for CBOR
                
                let joinedAllTimeCountValue = try value.toCBORValue()
                map = map.adding(key: "joinedAllTimeCount", value: joinedAllTimeCountValue)
            }
            
            
            
            
            
            if let value = labels {
                // Encode optional property even if it's an empty array for CBOR
                
                let labelsValue = try value.toCBORValue()
                map = map.adding(key: "labels", value: labelsValue)
            }
            
            
            
            
            
            
            let indexedAtValue = try indexedAt.toCBORValue()
            map = map.adding(key: "indexedAt", value: indexedAtValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
            case cid
            case record
            case creator
            case listItemCount
            case joinedWeekCount
            case joinedAllTimeCount
            case labels
            case indexedAt
        }
    }
        
public struct ListViewerState: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.graph.defs#listViewerState"
            public let muted: Bool?
            public let blocked: ATProtocolURI?

        // Standard initializer
        public init(
            muted: Bool?, blocked: ATProtocolURI?
        ) {
            
            self.muted = muted
            self.blocked = blocked
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.muted = try container.decodeIfPresent(Bool.self, forKey: .muted)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'muted': \(error)")
                
                throw error
            }
            do {
                
                
                self.blocked = try container.decodeIfPresent(ATProtocolURI.self, forKey: .blocked)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'blocked': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(muted, forKey: .muted)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(blocked, forKey: .blocked)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            if let value = muted {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = blocked {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if muted != other.muted {
                return false
            }
            
            
            
            
            if blocked != other.blocked {
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

            
            
            
            if let value = muted {
                // Encode optional property even if it's an empty array for CBOR
                
                let mutedValue = try value.toCBORValue()
                map = map.adding(key: "muted", value: mutedValue)
            }
            
            
            
            
            
            if let value = blocked {
                // Encode optional property even if it's an empty array for CBOR
                
                let blockedValue = try value.toCBORValue()
                map = map.adding(key: "blocked", value: blockedValue)
            }
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case muted
            case blocked
        }
    }
        
public struct NotFoundActor: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.graph.defs#notFoundActor"
            public let actor: ATIdentifier
            public let notFound: Bool

        // Standard initializer
        public init(
            actor: ATIdentifier, notFound: Bool
        ) {
            
            self.actor = actor
            self.notFound = notFound
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.actor = try container.decode(ATIdentifier.self, forKey: .actor)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'actor': \(error)")
                
                throw error
            }
            do {
                
                
                self.notFound = try container.decode(Bool.self, forKey: .notFound)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'notFound': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(actor, forKey: .actor)
            
            
            
            
            try container.encode(notFound, forKey: .notFound)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(actor)
            hasher.combine(notFound)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.actor != other.actor {
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let actorValue = try actor.toCBORValue()
            map = map.adding(key: "actor", value: actorValue)
            
            
            
            
            
            
            let notFoundValue = try notFound.toCBORValue()
            map = map.adding(key: "notFound", value: notFoundValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case actor
            case notFound
        }
    }
        
public struct Relationship: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.graph.defs#relationship"
            public let did: DID
            public let following: ATProtocolURI?
            public let followedBy: ATProtocolURI?

        // Standard initializer
        public init(
            did: DID, following: ATProtocolURI?, followedBy: ATProtocolURI?
        ) {
            
            self.did = did
            self.following = following
            self.followedBy = followedBy
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
            do {
                
                
                self.following = try container.decodeIfPresent(ATProtocolURI.self, forKey: .following)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'following': \(error)")
                
                throw error
            }
            do {
                
                
                self.followedBy = try container.decodeIfPresent(ATProtocolURI.self, forKey: .followedBy)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'followedBy': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(did, forKey: .did)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(following, forKey: .following)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(followedBy, forKey: .followedBy)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(did)
            if let value = following {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = followedBy {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.did != other.did {
                return false
            }
            
            
            
            
            if following != other.following {
                return false
            }
            
            
            
            
            if followedBy != other.followedBy {
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
            
            
            
            
            
            if let value = following {
                // Encode optional property even if it's an empty array for CBOR
                
                let followingValue = try value.toCBORValue()
                map = map.adding(key: "following", value: followingValue)
            }
            
            
            
            
            
            if let value = followedBy {
                // Encode optional property even if it's an empty array for CBOR
                
                let followedByValue = try value.toCBORValue()
                map = map.adding(key: "followedBy", value: followedByValue)
            }
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
            case following
            case followedBy
        }
    }



public struct ListPurpose: Codable, ATProtocolCodable, ATProtocolValue {
            public let rawValue: String
            
            // Predefined constants
            // 
            public static let appbskygraphdefsmodlist = ListPurpose(rawValue: "app.bsky.graph.defs#modlist")
            // 
            public static let appbskygraphdefscuratelist = ListPurpose(rawValue: "app.bsky.graph.defs#curatelist")
            // 
            public static let appbskygraphdefsreferencelist = ListPurpose(rawValue: "app.bsky.graph.defs#referencelist")
            
            public init(rawValue: String) {
                self.rawValue = rawValue
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                rawValue = try container.decode(String.self)
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode(rawValue)
            }
            
            public func isEqual(to other: any ATProtocolValue) -> Bool {
                guard let otherValue = other as? ListPurpose else { return false }
                return self.rawValue == otherValue.rawValue
            }
            
            // DAGCBOR encoding with field ordering
            public func toCBORValue() throws -> Any {
                // For string-based enum types, we return the raw string value directly
                return rawValue
            }
            
            // Provide allCases-like functionality
            public static var predefinedValues: [ListPurpose] {
                return [
                    .appbskygraphdefsmodlist,
                    .appbskygraphdefscuratelist,
                    .appbskygraphdefsreferencelist,
                ]
            }
        }


}


                           
