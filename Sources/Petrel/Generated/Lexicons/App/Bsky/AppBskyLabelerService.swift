import Foundation



// lexicon: 1, id: app.bsky.labeler.service


public struct AppBskyLabelerService: ATProtocolCodable, ATProtocolValue { 

    public static let typeIdentifier = "app.bsky.labeler.service"
        public let policies: AppBskyLabelerDefs.LabelerPolicies
        public let labels: AppBskyLabelerServiceLabelsUnion?
        public let createdAt: ATProtocolDate
        public let reasonTypes: [ComAtprotoModerationDefs.ReasonType]?
        public let subjectTypes: [ComAtprotoModerationDefs.SubjectType]?
        public let subjectCollections: [NSID]?

        public init(policies: AppBskyLabelerDefs.LabelerPolicies, labels: AppBskyLabelerServiceLabelsUnion?, createdAt: ATProtocolDate, reasonTypes: [ComAtprotoModerationDefs.ReasonType]?, subjectTypes: [ComAtprotoModerationDefs.SubjectType]?, subjectCollections: [NSID]?) {
            self.policies = policies
            self.labels = labels
            self.createdAt = createdAt
            self.reasonTypes = reasonTypes
            self.subjectTypes = subjectTypes
            self.subjectCollections = subjectCollections
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.policies = try container.decode(AppBskyLabelerDefs.LabelerPolicies.self, forKey: .policies)
            self.labels = try container.decodeIfPresent(AppBskyLabelerServiceLabelsUnion.self, forKey: .labels)
            self.createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
            self.reasonTypes = try container.decodeIfPresent([ComAtprotoModerationDefs.ReasonType].self, forKey: .reasonTypes)
            self.subjectTypes = try container.decodeIfPresent([ComAtprotoModerationDefs.SubjectType].self, forKey: .subjectTypes)
            self.subjectCollections = try container.decodeIfPresent([NSID].self, forKey: .subjectCollections)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(policies, forKey: .policies)
            try container.encodeIfPresent(labels, forKey: .labels)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encodeIfPresent(reasonTypes, forKey: .reasonTypes)
            try container.encodeIfPresent(subjectTypes, forKey: .subjectTypes)
            try container.encodeIfPresent(subjectCollections, forKey: .subjectCollections)
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
                hasher.combine(nil as Int?)
            }
            hasher.combine(createdAt)
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

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let policiesValue = try policies.toCBORValue()
            map = map.adding(key: "policies", value: policiesValue)
            if let value = labels {
                let labelsValue = try value.toCBORValue()
                map = map.adding(key: "labels", value: labelsValue)
            }
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            if let value = reasonTypes {
                let reasonTypesValue = try value.toCBORValue()
                map = map.adding(key: "reasonTypes", value: reasonTypesValue)
            }
            if let value = subjectTypes {
                let subjectTypesValue = try value.toCBORValue()
                map = map.adding(key: "subjectTypes", value: subjectTypesValue)
            }
            if let value = subjectCollections {
                let subjectCollectionsValue = try value.toCBORValue()
                map = map.adding(key: "subjectCollections", value: subjectCollectionsValue)
            }
            return map
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





public enum AppBskyLabelerServiceLabelsUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
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
        case .comAtprotoLabelDefsSelfLabels(let value):
            try container.encode("com.atproto.label.defs#selfLabels", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let container):
            try container.encode(to: encoder)
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .comAtprotoLabelDefsSelfLabels(let value):
            hasher.combine("com.atproto.label.defs#selfLabels")
            hasher.combine(value)
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: AppBskyLabelerServiceLabelsUnion, rhs: AppBskyLabelerServiceLabelsUnion) -> Bool {
        switch (lhs, rhs) {
        case (.comAtprotoLabelDefsSelfLabels(let lhsValue),
              .comAtprotoLabelDefsSelfLabels(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? AppBskyLabelerServiceLabelsUnion else { return false }
        return self == other
    }
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        // Create an ordered map to maintain field order
        var map = OrderedCBORMap()
        
        switch self {
        case .comAtprotoLabelDefsSelfLabels(let value):
            map = map.adding(key: "$type", value: "com.atproto.label.defs#selfLabels")
            
            let valueDict = try value.toCBORValue()

            // If the value is already an OrderedCBORMap, merge its entries
            if let orderedMap = valueDict as? OrderedCBORMap {
                for (key, value) in orderedMap.entries where key != "$type" {
                    map = map.adding(key: key, value: value)
                }
            } else if let dict = valueDict as? [String: Any] {
                // Otherwise add each key-value pair from the dictionary
                for (key, value) in dict where key != "$type" {
                    map = map.adding(key: key, value: value)
                }
            }
            return map
        case .unexpected(let container):
            return try container.toCBORValue()
        }
    }
}


}


                           

