import Foundation

// lexicon: 1, id: app.bsky.labeler.defs

public enum AppBskyLabelerDefs {
    public static let typeIdentifier = "app.bsky.labeler.defs"

    public struct LabelerView: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.labeler.defs#labelerView"
        public let uri: ATProtocolURI
        public let cid: String
        public let creator: AppBskyActorDefs.ProfileView
        public let likeCount: Int?
        public let viewer: LabelerViewerState?
        public let indexedAt: ATProtocolDate
        public let labels: [ComAtprotoLabelDefs.Label]?

        // Standard initializer
        public init(
            uri: ATProtocolURI, cid: String, creator: AppBskyActorDefs.ProfileView, likeCount: Int?, viewer: LabelerViewerState?, indexedAt: ATProtocolDate, labels: [ComAtprotoLabelDefs.Label]?
        ) {
            self.uri = uri
            self.cid = cid
            self.creator = creator
            self.likeCount = likeCount
            self.viewer = viewer
            self.indexedAt = indexedAt
            self.labels = labels
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
            do {
                cid = try container.decode(String.self, forKey: .cid)

            } catch {
                LogManager.logError("Decoding error for property 'cid': \(error)")
                throw error
            }
            do {
                creator = try container.decode(AppBskyActorDefs.ProfileView.self, forKey: .creator)

            } catch {
                LogManager.logError("Decoding error for property 'creator': \(error)")
                throw error
            }
            do {
                likeCount = try container.decodeIfPresent(Int.self, forKey: .likeCount)

            } catch {
                LogManager.logError("Decoding error for property 'likeCount': \(error)")
                throw error
            }
            do {
                viewer = try container.decodeIfPresent(LabelerViewerState.self, forKey: .viewer)

            } catch {
                LogManager.logError("Decoding error for property 'viewer': \(error)")
                throw error
            }
            do {
                indexedAt = try container.decode(ATProtocolDate.self, forKey: .indexedAt)

            } catch {
                LogManager.logError("Decoding error for property 'indexedAt': \(error)")
                throw error
            }
            do {
                labels = try container.decodeIfPresent([ComAtprotoLabelDefs.Label].self, forKey: .labels)

            } catch {
                LogManager.logError("Decoding error for property 'labels': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(uri, forKey: .uri)

            try container.encode(cid, forKey: .cid)

            try container.encode(creator, forKey: .creator)

            if let value = likeCount {
                try container.encode(value, forKey: .likeCount)
            }

            if let value = viewer {
                try container.encode(value, forKey: .viewer)
            }

            try container.encode(indexedAt, forKey: .indexedAt)

            if let value = labels {
                if !value.isEmpty {
                    try container.encode(value, forKey: .labels)
                }
            }
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

        // MARK: - PendingDataLoadable

        /// Check if any properties contain pending data that needs loading
        public var hasPendingData: Bool {
            var hasPending = false

            if !hasPending, let loadable = uri as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let loadable = cid as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let loadable = creator as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let value = likeCount, let loadable = value as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let value = viewer, let loadable = value as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let loadable = indexedAt as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let value = labels, let loadable = value as? PendingDataLoadable {
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

            if let loadable = cid as? PendingDataLoadable, loadable.hasPendingData {
                var mutableValue = loadable
                await mutableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = mutableValue as? String {
                    cid = updatedValue
                }
            }

            if let loadable = creator as? PendingDataLoadable, loadable.hasPendingData {
                var mutableValue = loadable
                await mutableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = mutableValue as? AppBskyActorDefs.ProfileView {
                    creator = updatedValue
                }
            }

            if let value = likeCount, var loadableValue = value as? PendingDataLoadable, loadableValue.hasPendingData {
                await loadableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = loadableValue as? Int {
                    likeCount = updatedValue
                }
            }

            if let value = viewer, var loadableValue = value as? PendingDataLoadable, loadableValue.hasPendingData {
                await loadableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = loadableValue as? LabelerViewerState {
                    viewer = updatedValue
                }
            }

            if let loadable = indexedAt as? PendingDataLoadable, loadable.hasPendingData {
                var mutableValue = loadable
                await mutableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = mutableValue as? ATProtocolDate {
                    indexedAt = updatedValue
                }
            }

            if let value = labels, var loadableValue = value as? PendingDataLoadable, loadableValue.hasPendingData {
                await loadableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = loadableValue as? [ComAtprotoLabelDefs.Label] {
                    labels = updatedValue
                }
            }
        }
    }

    public struct LabelerViewDetailed: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.labeler.defs#labelerViewDetailed"
        public let uri: ATProtocolURI
        public let cid: String
        public let creator: AppBskyActorDefs.ProfileView
        public let policies: AppBskyLabelerDefs.LabelerPolicies
        public let likeCount: Int?
        public let viewer: LabelerViewerState?
        public let indexedAt: ATProtocolDate
        public let labels: [ComAtprotoLabelDefs.Label]?
        public let reasonTypes: [ComAtprotoModerationDefs.ReasonType]?
        public let subjectTypes: [ComAtprotoModerationDefs.SubjectType]?
        public let subjectCollections: [String]?

        // Standard initializer
        public init(
            uri: ATProtocolURI, cid: String, creator: AppBskyActorDefs.ProfileView, policies: AppBskyLabelerDefs.LabelerPolicies, likeCount: Int?, viewer: LabelerViewerState?, indexedAt: ATProtocolDate, labels: [ComAtprotoLabelDefs.Label]?, reasonTypes: [ComAtprotoModerationDefs.ReasonType]?, subjectTypes: [ComAtprotoModerationDefs.SubjectType]?, subjectCollections: [String]?
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

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                uri = try container.decode(ATProtocolURI.self, forKey: .uri)

            } catch {
                LogManager.logError("Decoding error for property 'uri': \(error)")
                throw error
            }
            do {
                cid = try container.decode(String.self, forKey: .cid)

            } catch {
                LogManager.logError("Decoding error for property 'cid': \(error)")
                throw error
            }
            do {
                creator = try container.decode(AppBskyActorDefs.ProfileView.self, forKey: .creator)

            } catch {
                LogManager.logError("Decoding error for property 'creator': \(error)")
                throw error
            }
            do {
                policies = try container.decode(AppBskyLabelerDefs.LabelerPolicies.self, forKey: .policies)

            } catch {
                LogManager.logError("Decoding error for property 'policies': \(error)")
                throw error
            }
            do {
                likeCount = try container.decodeIfPresent(Int.self, forKey: .likeCount)

            } catch {
                LogManager.logError("Decoding error for property 'likeCount': \(error)")
                throw error
            }
            do {
                viewer = try container.decodeIfPresent(LabelerViewerState.self, forKey: .viewer)

            } catch {
                LogManager.logError("Decoding error for property 'viewer': \(error)")
                throw error
            }
            do {
                indexedAt = try container.decode(ATProtocolDate.self, forKey: .indexedAt)

            } catch {
                LogManager.logError("Decoding error for property 'indexedAt': \(error)")
                throw error
            }
            do {
                labels = try container.decodeIfPresent([ComAtprotoLabelDefs.Label].self, forKey: .labels)

            } catch {
                LogManager.logError("Decoding error for property 'labels': \(error)")
                throw error
            }
            do {
                reasonTypes = try container.decodeIfPresent([ComAtprotoModerationDefs.ReasonType].self, forKey: .reasonTypes)

            } catch {
                LogManager.logError("Decoding error for property 'reasonTypes': \(error)")
                throw error
            }
            do {
                subjectTypes = try container.decodeIfPresent([ComAtprotoModerationDefs.SubjectType].self, forKey: .subjectTypes)

            } catch {
                LogManager.logError("Decoding error for property 'subjectTypes': \(error)")
                throw error
            }
            do {
                subjectCollections = try container.decodeIfPresent([String].self, forKey: .subjectCollections)

            } catch {
                LogManager.logError("Decoding error for property 'subjectCollections': \(error)")
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

            if let value = likeCount {
                try container.encode(value, forKey: .likeCount)
            }

            if let value = viewer {
                try container.encode(value, forKey: .viewer)
            }

            try container.encode(indexedAt, forKey: .indexedAt)

            if let value = labels {
                if !value.isEmpty {
                    try container.encode(value, forKey: .labels)
                }
            }

            if let value = reasonTypes {
                if !value.isEmpty {
                    try container.encode(value, forKey: .reasonTypes)
                }
            }

            if let value = subjectTypes {
                if !value.isEmpty {
                    try container.encode(value, forKey: .subjectTypes)
                }
            }

            if let value = subjectCollections {
                if !value.isEmpty {
                    try container.encode(value, forKey: .subjectCollections)
                }
            }
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

        // MARK: - PendingDataLoadable

        /// Check if any properties contain pending data that needs loading
        public var hasPendingData: Bool {
            var hasPending = false

            if !hasPending, let loadable = uri as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let loadable = cid as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let loadable = creator as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let loadable = policies as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let value = likeCount, let loadable = value as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let value = viewer, let loadable = value as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let loadable = indexedAt as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let value = labels, let loadable = value as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let value = reasonTypes, let loadable = value as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let value = subjectTypes, let loadable = value as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let value = subjectCollections, let loadable = value as? PendingDataLoadable {
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

            if let loadable = cid as? PendingDataLoadable, loadable.hasPendingData {
                var mutableValue = loadable
                await mutableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = mutableValue as? String {
                    cid = updatedValue
                }
            }

            if let loadable = creator as? PendingDataLoadable, loadable.hasPendingData {
                var mutableValue = loadable
                await mutableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = mutableValue as? AppBskyActorDefs.ProfileView {
                    creator = updatedValue
                }
            }

            if let loadable = policies as? PendingDataLoadable, loadable.hasPendingData {
                var mutableValue = loadable
                await mutableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = mutableValue as? AppBskyLabelerDefs.LabelerPolicies {
                    policies = updatedValue
                }
            }

            if let value = likeCount, var loadableValue = value as? PendingDataLoadable, loadableValue.hasPendingData {
                await loadableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = loadableValue as? Int {
                    likeCount = updatedValue
                }
            }

            if let value = viewer, var loadableValue = value as? PendingDataLoadable, loadableValue.hasPendingData {
                await loadableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = loadableValue as? LabelerViewerState {
                    viewer = updatedValue
                }
            }

            if let loadable = indexedAt as? PendingDataLoadable, loadable.hasPendingData {
                var mutableValue = loadable
                await mutableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = mutableValue as? ATProtocolDate {
                    indexedAt = updatedValue
                }
            }

            if let value = labels, var loadableValue = value as? PendingDataLoadable, loadableValue.hasPendingData {
                await loadableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = loadableValue as? [ComAtprotoLabelDefs.Label] {
                    labels = updatedValue
                }
            }

            if let value = reasonTypes, var loadableValue = value as? PendingDataLoadable, loadableValue.hasPendingData {
                await loadableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = loadableValue as? [ComAtprotoModerationDefs.ReasonType] {
                    reasonTypes = updatedValue
                }
            }

            if let value = subjectTypes, var loadableValue = value as? PendingDataLoadable, loadableValue.hasPendingData {
                await loadableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = loadableValue as? [ComAtprotoModerationDefs.SubjectType] {
                    subjectTypes = updatedValue
                }
            }

            if let value = subjectCollections, var loadableValue = value as? PendingDataLoadable, loadableValue.hasPendingData {
                await loadableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = loadableValue as? [String] {
                    subjectCollections = updatedValue
                }
            }
        }
    }

    public struct LabelerViewerState: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.labeler.defs#labelerViewerState"
        public let like: ATProtocolURI?

        // Standard initializer
        public init(
            like: ATProtocolURI?
        ) {
            self.like = like
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                like = try container.decodeIfPresent(ATProtocolURI.self, forKey: .like)

            } catch {
                LogManager.logError("Decoding error for property 'like': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            if let value = like {
                try container.encode(value, forKey: .like)
            }
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

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case like
        }

        // MARK: - PendingDataLoadable

        /// Check if any properties contain pending data that needs loading
        public var hasPendingData: Bool {
            var hasPending = false

            if !hasPending, let value = like, let loadable = value as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            return hasPending
        }

        /// Load any pending data in properties
        public mutating func loadPendingData() async {
            if let value = like, var loadableValue = value as? PendingDataLoadable, loadableValue.hasPendingData {
                await loadableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = loadableValue as? ATProtocolURI {
                    like = updatedValue
                }
            }
        }
    }

    public struct LabelerPolicies: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.labeler.defs#labelerPolicies"
        public let labelValues: [ComAtprotoLabelDefs.LabelValue]
        public let labelValueDefinitions: [ComAtprotoLabelDefs.LabelValueDefinition]?

        // Standard initializer
        public init(
            labelValues: [ComAtprotoLabelDefs.LabelValue], labelValueDefinitions: [ComAtprotoLabelDefs.LabelValueDefinition]?
        ) {
            self.labelValues = labelValues
            self.labelValueDefinitions = labelValueDefinitions
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                labelValues = try container.decode([ComAtprotoLabelDefs.LabelValue].self, forKey: .labelValues)

            } catch {
                LogManager.logError("Decoding error for property 'labelValues': \(error)")
                throw error
            }
            do {
                labelValueDefinitions = try container.decodeIfPresent([ComAtprotoLabelDefs.LabelValueDefinition].self, forKey: .labelValueDefinitions)

            } catch {
                LogManager.logError("Decoding error for property 'labelValueDefinitions': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(labelValues, forKey: .labelValues)

            if let value = labelValueDefinitions {
                if !value.isEmpty {
                    try container.encode(value, forKey: .labelValueDefinitions)
                }
            }
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

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case labelValues
            case labelValueDefinitions
        }

        // MARK: - PendingDataLoadable

        /// Check if any properties contain pending data that needs loading
        public var hasPendingData: Bool {
            var hasPending = false

            if !hasPending, let loadable = labelValues as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let value = labelValueDefinitions, let loadable = value as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            return hasPending
        }

        /// Load any pending data in properties
        public mutating func loadPendingData() async {
            if let loadable = labelValues as? PendingDataLoadable, loadable.hasPendingData {
                var mutableValue = loadable
                await mutableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = mutableValue as? [ComAtprotoLabelDefs.LabelValue] {
                    labelValues = updatedValue
                }
            }

            if let value = labelValueDefinitions, var loadableValue = value as? PendingDataLoadable, loadableValue.hasPendingData {
                await loadableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = loadableValue as? [ComAtprotoLabelDefs.LabelValueDefinition] {
                    labelValueDefinitions = updatedValue
                }
            }
        }
    }
}
