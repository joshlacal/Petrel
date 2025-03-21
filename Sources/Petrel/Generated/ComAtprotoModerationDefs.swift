import Foundation

// lexicon: 1, id: com.atproto.moderation.defs

public enum ComAtprotoModerationDefs {
    public static let typeIdentifier = "com.atproto.moderation.defs"

    public enum ReasonType: Codable, ATProtocolCodable, ATProtocolValue {
        //
        case comatprotomoderationdefsreasonspam = "com.atproto.moderation.defs#reasonSpam"
        //
        case comatprotomoderationdefsreasonviolation = "com.atproto.moderation.defs#reasonViolation"
        //
        case comatprotomoderationdefsreasonmisleading = "com.atproto.moderation.defs#reasonMisleading"
        //
        case comatprotomoderationdefsreasonsexual = "com.atproto.moderation.defs#reasonSexual"
        //
        case comatprotomoderationdefsreasonrude = "com.atproto.moderation.defs#reasonRude"
        //
        case comatprotomoderationdefsreasonother = "com.atproto.moderation.defs#reasonOther"
        //
        case comatprotomoderationdefsreasonappeal = "com.atproto.moderation.defs#reasonAppeal"
        // Case for handling custom/unknown values
        case custom(String)

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)

            switch rawValue {
            case "com.atproto.moderation.defs#reasonSpam": self = .comatprotomoderationdefsreasonspam
            case "com.atproto.moderation.defs#reasonViolation": self = .comatprotomoderationdefsreasonviolation
            case "com.atproto.moderation.defs#reasonMisleading": self = .comatprotomoderationdefsreasonmisleading
            case "com.atproto.moderation.defs#reasonSexual": self = .comatprotomoderationdefsreasonsexual
            case "com.atproto.moderation.defs#reasonRude": self = .comatprotomoderationdefsreasonrude
            case "com.atproto.moderation.defs#reasonOther": self = .comatprotomoderationdefsreasonother
            case "com.atproto.moderation.defs#reasonAppeal": self = .comatprotomoderationdefsreasonappeal
            default: self = .custom(rawValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .comatprotomoderationdefsreasonspam:
                try container.encode("com.atproto.moderation.defs#reasonSpam")
            case .comatprotomoderationdefsreasonviolation:
                try container.encode("com.atproto.moderation.defs#reasonViolation")
            case .comatprotomoderationdefsreasonmisleading:
                try container.encode("com.atproto.moderation.defs#reasonMisleading")
            case .comatprotomoderationdefsreasonsexual:
                try container.encode("com.atproto.moderation.defs#reasonSexual")
            case .comatprotomoderationdefsreasonrude:
                try container.encode("com.atproto.moderation.defs#reasonRude")
            case .comatprotomoderationdefsreasonother:
                try container.encode("com.atproto.moderation.defs#reasonOther")
            case .comatprotomoderationdefsreasonappeal:
                try container.encode("com.atproto.moderation.defs#reasonAppeal")
            case let .custom(value):
                try container.encode(value)
            }
        }

        public var stringValue: String {
            switch self {
            case .comatprotomoderationdefsreasonspam: return "com.atproto.moderation.defs#reasonSpam"
            case .comatprotomoderationdefsreasonviolation: return "com.atproto.moderation.defs#reasonViolation"
            case .comatprotomoderationdefsreasonmisleading: return "com.atproto.moderation.defs#reasonMisleading"
            case .comatprotomoderationdefsreasonsexual: return "com.atproto.moderation.defs#reasonSexual"
            case .comatprotomoderationdefsreasonrude: return "com.atproto.moderation.defs#reasonRude"
            case .comatprotomoderationdefsreasonother: return "com.atproto.moderation.defs#reasonOther"
            case .comatprotomoderationdefsreasonappeal: return "com.atproto.moderation.defs#reasonAppeal"
            case let .custom(value): return value
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let otherEnum = other as? ReasonType else { return false }
            return stringValue == otherEnum.stringValue
        }

        public static var definedCases: [ReasonType] {
            return [
                .comatprotomoderationdefsreasonspam,
                .comatprotomoderationdefsreasonviolation,
                .comatprotomoderationdefsreasonmisleading,
                .comatprotomoderationdefsreasonsexual,
                .comatprotomoderationdefsreasonrude,
                .comatprotomoderationdefsreasonother,
                .comatprotomoderationdefsreasonappeal,
            ]
        }
    }

    public enum SubjectType: Codable, ATProtocolCodable, ATProtocolValue {
        //
        case account = "account"
        //
        case record = "record"
        //
        case chat = "chat"
        // Case for handling custom/unknown values
        case custom(String)

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)

            switch rawValue {
            case "account": self = .account
            case "record": self = .record
            case "chat": self = .chat
            default: self = .custom(rawValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .account:
                try container.encode("account")
            case .record:
                try container.encode("record")
            case .chat:
                try container.encode("chat")
            case let .custom(value):
                try container.encode(value)
            }
        }

        public var stringValue: String {
            switch self {
            case .account: return "account"
            case .record: return "record"
            case .chat: return "chat"
            case let .custom(value): return value
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let otherEnum = other as? SubjectType else { return false }
            return stringValue == otherEnum.stringValue
        }

        public static var definedCases: [SubjectType] {
            return [
                .account,
                .record,
                .chat,
            ]
        }
    }
}
