import Foundation

// lexicon: 1, id: app.bsky.labeler.service

public struct AppBskyLabelerService: ATProtocolCodable, ATProtocolValue {
    public static let typeIdentifier = "app.bsky.labeler.service"
    public let policies: AppBskyLabelerDefs.LabelerPolicies
    public let labels: AppBskyLabelerServiceLabelsUnion?
    public let createdAt: ATProtocolDate
    public let reasonTypes: [ComAtprotoModerationDefs.ReasonType]?
    public let subjectTypes: [ComAtprotoModerationDefs.SubjectType]?
    public let subjectCollections: [String]?

    // Standard initializer
    public init(policies: AppBskyLabelerDefs.LabelerPolicies, labels: AppBskyLabelerServiceLabelsUnion?, createdAt: ATProtocolDate, reasonTypes: [ComAtprotoModerationDefs.ReasonType]?, subjectTypes: [ComAtprotoModerationDefs.SubjectType]?, subjectCollections: [String]?) {
        self.policies = policies

        self.labels = labels

        self.createdAt = createdAt

        self.reasonTypes = reasonTypes

        self.subjectTypes = subjectTypes

        self.subjectCollections = subjectCollections
    }

    // Codable initializer
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        policies = try container.decode(AppBskyLabelerDefs.LabelerPolicies.self, forKey: .policies)

        labels = try container.decodeIfPresent(AppBskyLabelerServiceLabelsUnion.self, forKey: .labels)

        createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)

        reasonTypes = try container.decodeIfPresent([ComAtprotoModerationDefs.ReasonType].self, forKey: .reasonTypes)

        subjectTypes = try container.decodeIfPresent([ComAtprotoModerationDefs.SubjectType].self, forKey: .subjectTypes)

        subjectCollections = try container.decodeIfPresent([String].self, forKey: .subjectCollections)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Encode the $type field
        try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

        try container.encode(policies, forKey: .policies)

        if let value = labels {
            try container.encode(value, forKey: .labels)
        }

        try container.encode(createdAt, forKey: .createdAt)

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

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.isEqual(to: rhs)
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? Self else { return false }

        if policies != other.policies {
            return false
        }

        if labels != other.labels {
            return false
        }

        if createdAt != other.createdAt {
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

    public func hash(into hasher: inout Hasher) {
        hasher.combine(policies)
        if let value = labels {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?) // Placeholder for nil
        }
        hasher.combine(createdAt)
        if let value = reasonTypes {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?) // Placeholder for nil
        }
        if let value = subjectTypes {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?) // Placeholder for nil
        }
        if let value = subjectCollections {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?) // Placeholder for nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case typeIdentifier = "$type"
        case policies
        case labels
        case createdAt
        case reasonTypes
        case subjectTypes
        case subjectCollections
    }

    // MARK: - PendingDataLoadable

    /// Check if any properties contain pending data that needs loading
    public var hasPendingData: Bool {
        var hasPending = false

        if !hasPending, let loadable = policies as? PendingDataLoadable {
            hasPending = loadable.hasPendingData
        }

        if !hasPending, let value = labels, let loadable = value as? PendingDataLoadable {
            hasPending = loadable.hasPendingData
        }

        if !hasPending, let loadable = createdAt as? PendingDataLoadable {
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
        if let loadable = policies as? PendingDataLoadable, loadable.hasPendingData {
            var mutableValue = loadable
            await mutableValue.loadPendingData()
            // Only update if we can safely cast back to the expected type
            if let updatedValue = mutableValue as? AppBskyLabelerDefs.LabelerPolicies {
                policies = updatedValue
            }
        }

        if var value = labels as? (AppBskyLabelerServiceLabelsUnion & PendingDataLoadable), value.hasPendingData {
            await value.loadPendingData()
            labels = value
        }

        if let loadable = createdAt as? PendingDataLoadable, loadable.hasPendingData {
            var mutableValue = loadable
            await mutableValue.loadPendingData()
            // Only update if we can safely cast back to the expected type
            if let updatedValue = mutableValue as? ATProtocolDate {
                createdAt = updatedValue
            }
        }

        if var value = reasonTypes as? ([ComAtprotoModerationDefs.ReasonType] & PendingDataLoadable), value.hasPendingData {
            await value.loadPendingData()
            reasonTypes = value
        }

        if var value = subjectTypes as? ([ComAtprotoModerationDefs.SubjectType] & PendingDataLoadable), value.hasPendingData {
            await value.loadPendingData()
            subjectTypes = value
        }

        if var value = subjectCollections as? ([String] & PendingDataLoadable), value.hasPendingData {
            await value.loadPendingData()
            subjectCollections = value
        }
    }

    public enum AppBskyLabelerServiceLabelsUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, PendingDataLoadable, Equatable {
        case comAtprotoLabelDefsSelfLabels(ComAtprotoLabelDefs.SelfLabels)
        case unexpected(ATProtocolValueContainer)

        public init(_ value: ComAtprotoLabelDefs.SelfLabels) {
            self = .comAtprotoLabelDefsSelfLabels(value)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            switch typeValue {
            case "com.atproto.label.defs#selfLabels":
                let value = try ComAtprotoLabelDefs.SelfLabels(from: decoder)
                self = .comAtprotoLabelDefsSelfLabels(value)
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .comAtprotoLabelDefsSelfLabels(value):
                try container.encode("com.atproto.label.defs#selfLabels", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .comAtprotoLabelDefsSelfLabels(value):
                hasher.combine("com.atproto.label.defs#selfLabels")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: AppBskyLabelerServiceLabelsUnion, rhs: AppBskyLabelerServiceLabelsUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .comAtprotoLabelDefsSelfLabels(lhsValue),
                .comAtprotoLabelDefsSelfLabels(rhsValue)
            ):
                return lhsValue == rhsValue

            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)

            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? AppBskyLabelerServiceLabelsUnion else { return false }
            return self == other
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .comAtprotoLabelDefsSelfLabels(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case let .comAtprotoLabelDefsSelfLabels(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if var loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    await loadable.loadPendingData()
                    // Update the value if it was mutated (only if it's actually the expected type)
                    if let updatedValue = loadable as? ComAtprotoLabelDefs.SelfLabels {
                        self = .comAtprotoLabelDefsSelfLabels(updatedValue)
                    }
                }
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }
}
