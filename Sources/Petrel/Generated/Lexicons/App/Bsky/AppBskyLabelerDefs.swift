import Foundation

// lexicon: 1, id: app.bsky.labeler.defs

public enum AppBskyLabelerDefs {
    public static let typeIdentifier = "app.bsky.labeler.defs"

    public struct LabelerView: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.labeler.defs#labelerView"
        public let uri: ATProtocolURI
        public let cid: CID
        public let creator: AppBskyActorDefs.ProfileView
        public let likeCount: Int?
        public let viewer: LabelerViewerState?
        public let indexedAt: ATProtocolDate
        public let labels: [ComAtprotoLabelDefs.Label]?

        /// Standard initializer
        public init(
            uri: ATProtocolURI, cid: CID, creator: AppBskyActorDefs.ProfileView, likeCount: Int?, viewer: LabelerViewerState?, indexedAt: ATProtocolDate, labels: [ComAtprotoLabelDefs.Label]?
        ) {
            self.uri = uri
            self.cid = cid
            self.creator = creator
            self.likeCount = likeCount
            self.viewer = viewer
            self.indexedAt = indexedAt
            self.labels = labels
        }

        /// Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                uri = try container.decode(ATProtocolURI.self, forKey: .uri)

            } catch {
                LogManager.logError("Decoding error for required property 'uri': \(error)")

                throw error
            }
            do {
                cid = try container.decode(CID.self, forKey: .cid)

            } catch {
                LogManager.logError("Decoding error for required property 'cid': \(error)")

                throw error
            }
            do {
                creator = try container.decode(AppBskyActorDefs.ProfileView.self, forKey: .creator)

            } catch {
                LogManager.logError("Decoding error for required property 'creator': \(error)")

                throw error
            }
            do {
                likeCount = try container.decodeIfPresent(Int.self, forKey: .likeCount)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'likeCount': \(error)")

                throw error
            }
            do {
                viewer = try container.decodeIfPresent(LabelerViewerState.self, forKey: .viewer)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'viewer': \(error)")

                throw error
            }
            do {
                indexedAt = try container.decode(ATProtocolDate.self, forKey: .indexedAt)

            } catch {
                LogManager.logError("Decoding error for required property 'indexedAt': \(error)")

                throw error
            }
            do {
                labels = try container.decodeIfPresent([ComAtprotoLabelDefs.Label].self, forKey: .labels)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'labels': \(error)")

                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(uri, forKey: .uri)

            try container.encode(cid, forKey: .cid)

            try container.encode(creator, forKey: .creator)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(likeCount, forKey: .likeCount)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(viewer, forKey: .viewer)

            try container.encode(indexedAt, forKey: .indexedAt)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(labels, forKey: .labels)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
            hasher.combine(cid)
            hasher.combine(creator)
            if let value = likeCount {
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
            if let value = labels {
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

            if cid != other.cid {
                return false
            }

            if creator != other.creator {
                return false
            }

            if likeCount != other.likeCount {
                return false
            }

            if viewer != other.viewer {
                return false
            }

            if indexedAt != other.indexedAt {
                return false
            }

            if labels != other.labels {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let uriValue = try uri.toCBORValue()
            map = map.adding(key: "uri", value: uriValue)

            let cidValue = try cid.toCBORValue()
            map = map.adding(key: "cid", value: cidValue)

            let creatorValue = try creator.toCBORValue()
            map = map.adding(key: "creator", value: creatorValue)

            if let value = likeCount {
                // Encode optional property even if it's an empty array for CBOR

                let likeCountValue = try value.toCBORValue()
                map = map.adding(key: "likeCount", value: likeCountValue)
            }

            if let value = viewer {
                // Encode optional property even if it's an empty array for CBOR

                let viewerValue = try value.toCBORValue()
                map = map.adding(key: "viewer", value: viewerValue)
            }

            let indexedAtValue = try indexedAt.toCBORValue()
            map = map.adding(key: "indexedAt", value: indexedAtValue)

            if let value = labels {
                // Encode optional property even if it's an empty array for CBOR

                let labelsValue = try value.toCBORValue()
                map = map.adding(key: "labels", value: labelsValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
            case cid
            case creator
            case likeCount
            case viewer
            case indexedAt
            case labels
        }
    }

    public struct LabelerViewDetailed: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.labeler.defs#labelerViewDetailed"
        public let uri: ATProtocolURI
        public let cid: CID
        public let creator: AppBskyActorDefs.ProfileView
        public let policies: AppBskyLabelerDefs.LabelerPolicies
        public let likeCount: Int?
        public let viewer: LabelerViewerState?
        public let indexedAt: ATProtocolDate
        public let labels: [ComAtprotoLabelDefs.Label]?
        public let reasonTypes: [ComAtprotoModerationDefs.ReasonType]?
        public let subjectTypes: [ComAtprotoModerationDefs.SubjectType]?
        public let subjectCollections: [NSID]?

        /// Standard initializer
        public init(
            uri: ATProtocolURI, cid: CID, creator: AppBskyActorDefs.ProfileView, policies: AppBskyLabelerDefs.LabelerPolicies, likeCount: Int?, viewer: LabelerViewerState?, indexedAt: ATProtocolDate, labels: [ComAtprotoLabelDefs.Label]?, reasonTypes: [ComAtprotoModerationDefs.ReasonType]?, subjectTypes: [ComAtprotoModerationDefs.SubjectType]?, subjectCollections: [NSID]?
        ) {
            self.uri = uri
            self.cid = cid
            self.creator = creator
            self.policies = policies
            self.likeCount = likeCount
            self.viewer = viewer
            self.indexedAt = indexedAt
            self.labels = labels
            self.reasonTypes = reasonTypes
            self.subjectTypes = subjectTypes
            self.subjectCollections = subjectCollections
        }

        /// Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                uri = try container.decode(ATProtocolURI.self, forKey: .uri)

            } catch {
                LogManager.logError("Decoding error for required property 'uri': \(error)")

                throw error
            }
            do {
                cid = try container.decode(CID.self, forKey: .cid)

            } catch {
                LogManager.logError("Decoding error for required property 'cid': \(error)")

                throw error
            }
            do {
                creator = try container.decode(AppBskyActorDefs.ProfileView.self, forKey: .creator)

            } catch {
                LogManager.logError("Decoding error for required property 'creator': \(error)")

                throw error
            }
            do {
                policies = try container.decode(AppBskyLabelerDefs.LabelerPolicies.self, forKey: .policies)

            } catch {
                LogManager.logError("Decoding error for required property 'policies': \(error)")

                throw error
            }
            do {
                likeCount = try container.decodeIfPresent(Int.self, forKey: .likeCount)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'likeCount': \(error)")

                throw error
            }
            do {
                viewer = try container.decodeIfPresent(LabelerViewerState.self, forKey: .viewer)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'viewer': \(error)")

                throw error
            }
            do {
                indexedAt = try container.decode(ATProtocolDate.self, forKey: .indexedAt)

            } catch {
                LogManager.logError("Decoding error for required property 'indexedAt': \(error)")

                throw error
            }
            do {
                labels = try container.decodeIfPresent([ComAtprotoLabelDefs.Label].self, forKey: .labels)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'labels': \(error)")

                throw error
            }
            do {
                reasonTypes = try container.decodeIfPresent([ComAtprotoModerationDefs.ReasonType].self, forKey: .reasonTypes)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'reasonTypes': \(error)")

                throw error
            }
            do {
                subjectTypes = try container.decodeIfPresent([ComAtprotoModerationDefs.SubjectType].self, forKey: .subjectTypes)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'subjectTypes': \(error)")

                throw error
            }
            do {
                subjectCollections = try container.decodeIfPresent([NSID].self, forKey: .subjectCollections)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'subjectCollections': \(error)")

                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(uri, forKey: .uri)

            try container.encode(cid, forKey: .cid)

            try container.encode(creator, forKey: .creator)

            try container.encode(policies, forKey: .policies)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(likeCount, forKey: .likeCount)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(viewer, forKey: .viewer)

            try container.encode(indexedAt, forKey: .indexedAt)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(labels, forKey: .labels)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(reasonTypes, forKey: .reasonTypes)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(subjectTypes, forKey: .subjectTypes)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(subjectCollections, forKey: .subjectCollections)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
            hasher.combine(cid)
            hasher.combine(creator)
            hasher.combine(policies)
            if let value = likeCount {
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
            if let value = labels {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = reasonTypes {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = subjectTypes {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = subjectCollections {
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

            if cid != other.cid {
                return false
            }

            if creator != other.creator {
                return false
            }

            if policies != other.policies {
                return false
            }

            if likeCount != other.likeCount {
                return false
            }

            if viewer != other.viewer {
                return false
            }

            if indexedAt != other.indexedAt {
                return false
            }

            if labels != other.labels {
                return false
            }

            if reasonTypes != other.reasonTypes {
                return false
            }

            if subjectTypes != other.subjectTypes {
                return false
            }

            if subjectCollections != other.subjectCollections {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let uriValue = try uri.toCBORValue()
            map = map.adding(key: "uri", value: uriValue)

            let cidValue = try cid.toCBORValue()
            map = map.adding(key: "cid", value: cidValue)

            let creatorValue = try creator.toCBORValue()
            map = map.adding(key: "creator", value: creatorValue)

            let policiesValue = try policies.toCBORValue()
            map = map.adding(key: "policies", value: policiesValue)

            if let value = likeCount {
                // Encode optional property even if it's an empty array for CBOR

                let likeCountValue = try value.toCBORValue()
                map = map.adding(key: "likeCount", value: likeCountValue)
            }

            if let value = viewer {
                // Encode optional property even if it's an empty array for CBOR

                let viewerValue = try value.toCBORValue()
                map = map.adding(key: "viewer", value: viewerValue)
            }

            let indexedAtValue = try indexedAt.toCBORValue()
            map = map.adding(key: "indexedAt", value: indexedAtValue)

            if let value = labels {
                // Encode optional property even if it's an empty array for CBOR

                let labelsValue = try value.toCBORValue()
                map = map.adding(key: "labels", value: labelsValue)
            }

            if let value = reasonTypes {
                // Encode optional property even if it's an empty array for CBOR

                let reasonTypesValue = try value.toCBORValue()
                map = map.adding(key: "reasonTypes", value: reasonTypesValue)
            }

            if let value = subjectTypes {
                // Encode optional property even if it's an empty array for CBOR

                let subjectTypesValue = try value.toCBORValue()
                map = map.adding(key: "subjectTypes", value: subjectTypesValue)
            }

            if let value = subjectCollections {
                // Encode optional property even if it's an empty array for CBOR

                let subjectCollectionsValue = try value.toCBORValue()
                map = map.adding(key: "subjectCollections", value: subjectCollectionsValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
            case cid
            case creator
            case policies
            case likeCount
            case viewer
            case indexedAt
            case labels
            case reasonTypes
            case subjectTypes
            case subjectCollections
        }
    }

    public struct LabelerViewerState: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.labeler.defs#labelerViewerState"
        public let like: ATProtocolURI?

        /// Standard initializer
        public init(
            like: ATProtocolURI?
        ) {
            self.like = like
        }

        /// Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                like = try container.decodeIfPresent(ATProtocolURI.self, forKey: .like)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'like': \(error)")

                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(like, forKey: .like)
        }

        public func hash(into hasher: inout Hasher) {
            if let value = like {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if like != other.like {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            if let value = like {
                // Encode optional property even if it's an empty array for CBOR

                let likeValue = try value.toCBORValue()
                map = map.adding(key: "like", value: likeValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case like
        }
    }

    public struct LabelerPolicies: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.labeler.defs#labelerPolicies"
        public let labelValues: [ComAtprotoLabelDefs.LabelValue]
        public let labelValueDefinitions: [ComAtprotoLabelDefs.LabelValueDefinition]?

        /// Standard initializer
        public init(
            labelValues: [ComAtprotoLabelDefs.LabelValue], labelValueDefinitions: [ComAtprotoLabelDefs.LabelValueDefinition]?
        ) {
            self.labelValues = labelValues
            self.labelValueDefinitions = labelValueDefinitions
        }

        /// Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                labelValues = try container.decode([ComAtprotoLabelDefs.LabelValue].self, forKey: .labelValues)

            } catch {
                LogManager.logError("Decoding error for required property 'labelValues': \(error)")

                throw error
            }
            do {
                labelValueDefinitions = try container.decodeIfPresent([ComAtprotoLabelDefs.LabelValueDefinition].self, forKey: .labelValueDefinitions)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'labelValueDefinitions': \(error)")

                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(labelValues, forKey: .labelValues)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(labelValueDefinitions, forKey: .labelValueDefinitions)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(labelValues)
            if let value = labelValueDefinitions {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if labelValues != other.labelValues {
                return false
            }

            if labelValueDefinitions != other.labelValueDefinitions {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let labelValuesValue = try labelValues.toCBORValue()
            map = map.adding(key: "labelValues", value: labelValuesValue)

            if let value = labelValueDefinitions {
                // Encode optional property even if it's an empty array for CBOR

                let labelValueDefinitionsValue = try value.toCBORValue()
                map = map.adding(key: "labelValueDefinitions", value: labelValueDefinitionsValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case labelValues
            case labelValueDefinitions
        }
    }
}
