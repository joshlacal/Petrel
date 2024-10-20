import Foundation
import ZippyJSON


// lexicon: 1, id: app.bsky.actor.profile


public struct AppBskyActorProfile: ATProtocolCodable, ATProtocolValue { 

    public static let typeIdentifier = "app.bsky.actor.profile"
        public let displayName: String?
        public let description: String?
        public let avatar: Blob?
        public let banner: Blob?
        public let labels: AppBskyActorProfileLabelsUnion?
        public let joinedViaStarterPack: ComAtprotoRepoStrongRef?
        public let createdAt: ATProtocolDate?

        // Standard initializer
        public init(displayName: String?, description: String?, avatar: Blob?, banner: Blob?, labels: AppBskyActorProfileLabelsUnion?, joinedViaStarterPack: ComAtprotoRepoStrongRef?, createdAt: ATProtocolDate?) {
            
            self.displayName = displayName
            
            self.description = description
            
            self.avatar = avatar
            
            self.banner = banner
            
            self.labels = labels
            
            self.joinedViaStarterPack = joinedViaStarterPack
            
            self.createdAt = createdAt
            
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
            
            
            self.description = try container.decodeIfPresent(String.self, forKey: .description)
            
            
            self.avatar = try container.decodeIfPresent(Blob.self, forKey: .avatar)
            
            
            self.banner = try container.decodeIfPresent(Blob.self, forKey: .banner)
            
            
            self.labels = try container.decodeIfPresent(AppBskyActorProfileLabelsUnion.self, forKey: .labels)
            
            
            self.joinedViaStarterPack = try container.decodeIfPresent(ComAtprotoRepoStrongRef.self, forKey: .joinedViaStarterPack)
            
            
            self.createdAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .createdAt)
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            // Encode the $type field
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            if let value = displayName {
                try container.encode(value, forKey: .displayName)
            }
            
            
            if let value = description {
                try container.encode(value, forKey: .description)
            }
            
            
            if let value = avatar {
                try container.encode(value, forKey: .avatar)
            }
            
            
            if let value = banner {
                try container.encode(value, forKey: .banner)
            }
            
            
            if let value = labels {
                try container.encode(value, forKey: .labels)
            }
            
            
            if let value = joinedViaStarterPack {
                try container.encode(value, forKey: .joinedViaStarterPack)
            }
            
            
            if let value = createdAt {
                try container.encode(value, forKey: .createdAt)
            }
            
        }
                                            
        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            
            if displayName != other.displayName {
                return false
            }
            
            
            if description != other.description {
                return false
            }
            
            
            if avatar != other.avatar {
                return false
            }
            
            
            if banner != other.banner {
                return false
            }
            
            
            if labels != other.labels {
                return false
            }
            
            
            if joinedViaStarterPack != other.joinedViaStarterPack {
                return false
            }
            
            
            if createdAt != other.createdAt {
                return false
            }
            
            return true
        }
        

        public func hash(into hasher: inout Hasher) {
            if let value = displayName {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?) // Placeholder for nil
            }
            if let value = description {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?) // Placeholder for nil
            }
            if let value = avatar {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?) // Placeholder for nil
            }
            if let value = banner {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?) // Placeholder for nil
            }
            if let value = labels {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?) // Placeholder for nil
            }
            if let value = joinedViaStarterPack {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?) // Placeholder for nil
            }
            if let value = createdAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?) // Placeholder for nil
            }
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case displayName
            case description
            case avatar
            case banner
            case labels
            case joinedViaStarterPack
            case createdAt
        }





public enum AppBskyActorProfileLabelsUnion: Codable, ATProtocolCodable, ATProtocolValue {
    case comAtprotoLabelDefsSelfLabels(ComAtprotoLabelDefs.SelfLabels)
    case unexpected(ATProtocolValueContainer)

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
        case .unexpected(let ATProtocolValueContainer):
            try ATProtocolValueContainer.encode(to: encoder)
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .comAtprotoLabelDefsSelfLabels(let value):
            hasher.combine("com.atproto.label.defs#selfLabels")
            hasher.combine(value)
        case .unexpected(let ATProtocolValueContainer):
            hasher.combine("unexpected")
            hasher.combine(ATProtocolValueContainer)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherValue = other as? AppBskyActorProfileLabelsUnion else { return false }

        switch (self, otherValue) {
            case (.comAtprotoLabelDefsSelfLabels(let selfValue), 
                .comAtprotoLabelDefsSelfLabels(let otherValue)):
                return selfValue == otherValue
            case (.unexpected(let selfValue), .unexpected(let otherValue)):
                return selfValue.isEqual(to: otherValue)
            default:
                return false
        }
    }
}


}


                           
