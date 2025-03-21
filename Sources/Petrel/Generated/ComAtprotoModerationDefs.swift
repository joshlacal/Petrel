import Foundation

// lexicon: 1, id: com.atproto.moderation.defs

public enum ComAtprotoModerationDefs {
    public static let typeIdentifier = "com.atproto.moderation.defs"

    public struct ReasonType: Codable, ATProtocolCodable, ATProtocolValue {
        public let rawValue: String

        // Predefined constants
        //
        public static let comAtprotoModerationDefsReasonSpam = ReasonType(rawValue: "com.atproto.moderation.defs#reasonSpam")
        //
        public static let comAtprotoModerationDefsReasonViolation = ReasonType(rawValue: "com.atproto.moderation.defs#reasonViolation")
        //
        public static let comAtprotoModerationDefsReasonMisleading = ReasonType(rawValue: "com.atproto.moderation.defs#reasonMisleading")
        //
        public static let comAtprotoModerationDefsReasonSexual = ReasonType(rawValue: "com.atproto.moderation.defs#reasonSexual")
        //
        public static let comAtprotoModerationDefsReasonRude = ReasonType(rawValue: "com.atproto.moderation.defs#reasonRude")
        //
        public static let comAtprotoModerationDefsReasonOther = ReasonType(rawValue: "com.atproto.moderation.defs#reasonOther")
        //
        public static let comAtprotoModerationDefsReasonAppeal = ReasonType(rawValue: "com.atproto.moderation.defs#reasonAppeal")

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
            guard let otherValue = other as? ReasonType else { return false }
            return rawValue == otherValue.rawValue
        }

        // Provide allCases-like functionality
        public static var predefinedValues: [ReasonType] {
            return [
                .comAtprotoModerationDefsReasonSpam,
                .comAtprotoModerationDefsReasonViolation,
                .comAtprotoModerationDefsReasonMisleading,
                .comAtprotoModerationDefsReasonSexual,
                .comAtprotoModerationDefsReasonRude,
                .comAtprotoModerationDefsReasonOther,
                .comAtprotoModerationDefsReasonAppeal,
            ]
        }
    }

    public struct SubjectType: Codable, ATProtocolCodable, ATProtocolValue {
        public let rawValue: String

        // Predefined constants
        //
        public static let account = SubjectType(rawValue: "account")
        //
        public static let record = SubjectType(rawValue: "record")
        //
        public static let chat = SubjectType(rawValue: "chat")

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
            guard let otherValue = other as? SubjectType else { return false }
            return rawValue == otherValue.rawValue
        }

        // Provide allCases-like functionality
        public static var predefinedValues: [SubjectType] {
            return [
                .account,
                .record,
                .chat,
            ]
        }
    }
}
