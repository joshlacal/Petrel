import Foundation



// lexicon: 1, id: com.atproto.moderation.defs


public struct ComAtprotoModerationDefs { 

    public static let typeIdentifier = "com.atproto.moderation.defs"



public struct ReasonType: Codable, ATProtocolCodable, ATProtocolValue {
            public let rawValue: String
            
            // Predefined constants
            // 
            public static let comatprotomoderationdefsreasonspam = ReasonType(rawValue: "com.atproto.moderation.defs#reasonSpam")
            // 
            public static let comatprotomoderationdefsreasonviolation = ReasonType(rawValue: "com.atproto.moderation.defs#reasonViolation")
            // 
            public static let comatprotomoderationdefsreasonmisleading = ReasonType(rawValue: "com.atproto.moderation.defs#reasonMisleading")
            // 
            public static let comatprotomoderationdefsreasonsexual = ReasonType(rawValue: "com.atproto.moderation.defs#reasonSexual")
            // 
            public static let comatprotomoderationdefsreasonrude = ReasonType(rawValue: "com.atproto.moderation.defs#reasonRude")
            // 
            public static let comatprotomoderationdefsreasonother = ReasonType(rawValue: "com.atproto.moderation.defs#reasonOther")
            // 
            public static let comatprotomoderationdefsreasonappeal = ReasonType(rawValue: "com.atproto.moderation.defs#reasonAppeal")
            
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
                return self.rawValue == otherValue.rawValue
            }
            
            // DAGCBOR encoding with field ordering
            public func toCBORValue() throws -> Any {
                // For string-based enum types, we return the raw string value directly
                return rawValue
            }
            
            // Provide allCases-like functionality
            public static var predefinedValues: [ReasonType] {
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
                return self.rawValue == otherValue.rawValue
            }
            
            // DAGCBOR encoding with field ordering
            public func toCBORValue() throws -> Any {
                // For string-based enum types, we return the raw string value directly
                return rawValue
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


                           
