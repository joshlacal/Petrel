import Foundation
import ZippyJSON

// lexicon: 1, id: com.atproto.moderation.defs

public enum ComAtprotoModerationDefs {
    public static let typeIdentifier = "com.atproto.moderation.defs"

    public enum ReasonType: String, Codable, ATProtocolCodable, ATProtocolValue, CaseIterable {
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

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let otherEnum = other as? ReasonType else { return false }
            return rawValue == otherEnum.rawValue
        }
    }
}
