import Foundation
import ZippyJSON


// lexicon: 1, id: tools.ozone.moderation.emitEvent


public struct ToolsOzoneModerationEmitEvent { 

    public static let typeIdentifier = "tools.ozone.moderation.emitEvent"        
public struct Input: ATProtocolCodable {
            public let event: InputEventUnion
            public let subject: InputSubjectUnion
            public let subjectBlobCids: [String]?
            public let createdBy: String

            // Standard public initializer
            public init(event: InputEventUnion, subject: InputSubjectUnion, subjectBlobCids: [String]? = nil, createdBy: String) {
                self.event = event
                self.subject = subject
                self.subjectBlobCids = subjectBlobCids
                self.createdBy = createdBy
                
            }
        }    
    public typealias Output = ToolsOzoneModerationDefs.ModEventView
            
public enum Error: String, Swift.Error, CustomStringConvertible {
                case subjectHasAction = "SubjectHasAction."
            public var description: String {
                return self.rawValue
            }
        }





public enum InputEventUnion: Codable, ATProtocolCodable, ATProtocolValue {
    case toolsOzoneModerationDefsModEventTakedown(ToolsOzoneModerationDefs.ModEventTakedown)
    case toolsOzoneModerationDefsModEventAcknowledge(ToolsOzoneModerationDefs.ModEventAcknowledge)
    case toolsOzoneModerationDefsModEventEscalate(ToolsOzoneModerationDefs.ModEventEscalate)
    case toolsOzoneModerationDefsModEventComment(ToolsOzoneModerationDefs.ModEventComment)
    case toolsOzoneModerationDefsModEventLabel(ToolsOzoneModerationDefs.ModEventLabel)
    case toolsOzoneModerationDefsModEventReport(ToolsOzoneModerationDefs.ModEventReport)
    case toolsOzoneModerationDefsModEventMute(ToolsOzoneModerationDefs.ModEventMute)
    case toolsOzoneModerationDefsModEventUnmute(ToolsOzoneModerationDefs.ModEventUnmute)
    case toolsOzoneModerationDefsModEventMuteReporter(ToolsOzoneModerationDefs.ModEventMuteReporter)
    case toolsOzoneModerationDefsModEventUnmuteReporter(ToolsOzoneModerationDefs.ModEventUnmuteReporter)
    case toolsOzoneModerationDefsModEventReverseTakedown(ToolsOzoneModerationDefs.ModEventReverseTakedown)
    case toolsOzoneModerationDefsModEventResolveAppeal(ToolsOzoneModerationDefs.ModEventResolveAppeal)
    case toolsOzoneModerationDefsModEventEmail(ToolsOzoneModerationDefs.ModEventEmail)
    case toolsOzoneModerationDefsModEventTag(ToolsOzoneModerationDefs.ModEventTag)
    case unexpected(ATProtocolValueContainer)

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)

        switch typeValue {
        case "tools.ozone.moderation.defs#modEventTakedown":
            let value = try ToolsOzoneModerationDefs.ModEventTakedown(from: decoder)
            self = .toolsOzoneModerationDefsModEventTakedown(value)
        case "tools.ozone.moderation.defs#modEventAcknowledge":
            let value = try ToolsOzoneModerationDefs.ModEventAcknowledge(from: decoder)
            self = .toolsOzoneModerationDefsModEventAcknowledge(value)
        case "tools.ozone.moderation.defs#modEventEscalate":
            let value = try ToolsOzoneModerationDefs.ModEventEscalate(from: decoder)
            self = .toolsOzoneModerationDefsModEventEscalate(value)
        case "tools.ozone.moderation.defs#modEventComment":
            let value = try ToolsOzoneModerationDefs.ModEventComment(from: decoder)
            self = .toolsOzoneModerationDefsModEventComment(value)
        case "tools.ozone.moderation.defs#modEventLabel":
            let value = try ToolsOzoneModerationDefs.ModEventLabel(from: decoder)
            self = .toolsOzoneModerationDefsModEventLabel(value)
        case "tools.ozone.moderation.defs#modEventReport":
            let value = try ToolsOzoneModerationDefs.ModEventReport(from: decoder)
            self = .toolsOzoneModerationDefsModEventReport(value)
        case "tools.ozone.moderation.defs#modEventMute":
            let value = try ToolsOzoneModerationDefs.ModEventMute(from: decoder)
            self = .toolsOzoneModerationDefsModEventMute(value)
        case "tools.ozone.moderation.defs#modEventUnmute":
            let value = try ToolsOzoneModerationDefs.ModEventUnmute(from: decoder)
            self = .toolsOzoneModerationDefsModEventUnmute(value)
        case "tools.ozone.moderation.defs#modEventMuteReporter":
            let value = try ToolsOzoneModerationDefs.ModEventMuteReporter(from: decoder)
            self = .toolsOzoneModerationDefsModEventMuteReporter(value)
        case "tools.ozone.moderation.defs#modEventUnmuteReporter":
            let value = try ToolsOzoneModerationDefs.ModEventUnmuteReporter(from: decoder)
            self = .toolsOzoneModerationDefsModEventUnmuteReporter(value)
        case "tools.ozone.moderation.defs#modEventReverseTakedown":
            let value = try ToolsOzoneModerationDefs.ModEventReverseTakedown(from: decoder)
            self = .toolsOzoneModerationDefsModEventReverseTakedown(value)
        case "tools.ozone.moderation.defs#modEventResolveAppeal":
            let value = try ToolsOzoneModerationDefs.ModEventResolveAppeal(from: decoder)
            self = .toolsOzoneModerationDefsModEventResolveAppeal(value)
        case "tools.ozone.moderation.defs#modEventEmail":
            let value = try ToolsOzoneModerationDefs.ModEventEmail(from: decoder)
            self = .toolsOzoneModerationDefsModEventEmail(value)
        case "tools.ozone.moderation.defs#modEventTag":
            let value = try ToolsOzoneModerationDefs.ModEventTag(from: decoder)
            self = .toolsOzoneModerationDefsModEventTag(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .toolsOzoneModerationDefsModEventTakedown(let value):
            try container.encode("tools.ozone.moderation.defs#modEventTakedown", forKey: .type)
            try value.encode(to: encoder)
        case .toolsOzoneModerationDefsModEventAcknowledge(let value):
            try container.encode("tools.ozone.moderation.defs#modEventAcknowledge", forKey: .type)
            try value.encode(to: encoder)
        case .toolsOzoneModerationDefsModEventEscalate(let value):
            try container.encode("tools.ozone.moderation.defs#modEventEscalate", forKey: .type)
            try value.encode(to: encoder)
        case .toolsOzoneModerationDefsModEventComment(let value):
            try container.encode("tools.ozone.moderation.defs#modEventComment", forKey: .type)
            try value.encode(to: encoder)
        case .toolsOzoneModerationDefsModEventLabel(let value):
            try container.encode("tools.ozone.moderation.defs#modEventLabel", forKey: .type)
            try value.encode(to: encoder)
        case .toolsOzoneModerationDefsModEventReport(let value):
            try container.encode("tools.ozone.moderation.defs#modEventReport", forKey: .type)
            try value.encode(to: encoder)
        case .toolsOzoneModerationDefsModEventMute(let value):
            try container.encode("tools.ozone.moderation.defs#modEventMute", forKey: .type)
            try value.encode(to: encoder)
        case .toolsOzoneModerationDefsModEventUnmute(let value):
            try container.encode("tools.ozone.moderation.defs#modEventUnmute", forKey: .type)
            try value.encode(to: encoder)
        case .toolsOzoneModerationDefsModEventMuteReporter(let value):
            try container.encode("tools.ozone.moderation.defs#modEventMuteReporter", forKey: .type)
            try value.encode(to: encoder)
        case .toolsOzoneModerationDefsModEventUnmuteReporter(let value):
            try container.encode("tools.ozone.moderation.defs#modEventUnmuteReporter", forKey: .type)
            try value.encode(to: encoder)
        case .toolsOzoneModerationDefsModEventReverseTakedown(let value):
            try container.encode("tools.ozone.moderation.defs#modEventReverseTakedown", forKey: .type)
            try value.encode(to: encoder)
        case .toolsOzoneModerationDefsModEventResolveAppeal(let value):
            try container.encode("tools.ozone.moderation.defs#modEventResolveAppeal", forKey: .type)
            try value.encode(to: encoder)
        case .toolsOzoneModerationDefsModEventEmail(let value):
            try container.encode("tools.ozone.moderation.defs#modEventEmail", forKey: .type)
            try value.encode(to: encoder)
        case .toolsOzoneModerationDefsModEventTag(let value):
            try container.encode("tools.ozone.moderation.defs#modEventTag", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let ATProtocolValueContainer):
            try ATProtocolValueContainer.encode(to: encoder)
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .toolsOzoneModerationDefsModEventTakedown(let value):
            hasher.combine("tools.ozone.moderation.defs#modEventTakedown")
            hasher.combine(value)
        case .toolsOzoneModerationDefsModEventAcknowledge(let value):
            hasher.combine("tools.ozone.moderation.defs#modEventAcknowledge")
            hasher.combine(value)
        case .toolsOzoneModerationDefsModEventEscalate(let value):
            hasher.combine("tools.ozone.moderation.defs#modEventEscalate")
            hasher.combine(value)
        case .toolsOzoneModerationDefsModEventComment(let value):
            hasher.combine("tools.ozone.moderation.defs#modEventComment")
            hasher.combine(value)
        case .toolsOzoneModerationDefsModEventLabel(let value):
            hasher.combine("tools.ozone.moderation.defs#modEventLabel")
            hasher.combine(value)
        case .toolsOzoneModerationDefsModEventReport(let value):
            hasher.combine("tools.ozone.moderation.defs#modEventReport")
            hasher.combine(value)
        case .toolsOzoneModerationDefsModEventMute(let value):
            hasher.combine("tools.ozone.moderation.defs#modEventMute")
            hasher.combine(value)
        case .toolsOzoneModerationDefsModEventUnmute(let value):
            hasher.combine("tools.ozone.moderation.defs#modEventUnmute")
            hasher.combine(value)
        case .toolsOzoneModerationDefsModEventMuteReporter(let value):
            hasher.combine("tools.ozone.moderation.defs#modEventMuteReporter")
            hasher.combine(value)
        case .toolsOzoneModerationDefsModEventUnmuteReporter(let value):
            hasher.combine("tools.ozone.moderation.defs#modEventUnmuteReporter")
            hasher.combine(value)
        case .toolsOzoneModerationDefsModEventReverseTakedown(let value):
            hasher.combine("tools.ozone.moderation.defs#modEventReverseTakedown")
            hasher.combine(value)
        case .toolsOzoneModerationDefsModEventResolveAppeal(let value):
            hasher.combine("tools.ozone.moderation.defs#modEventResolveAppeal")
            hasher.combine(value)
        case .toolsOzoneModerationDefsModEventEmail(let value):
            hasher.combine("tools.ozone.moderation.defs#modEventEmail")
            hasher.combine(value)
        case .toolsOzoneModerationDefsModEventTag(let value):
            hasher.combine("tools.ozone.moderation.defs#modEventTag")
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
        guard let otherValue = other as? InputEventUnion else { return false }

        switch (self, otherValue) {
            case (.toolsOzoneModerationDefsModEventTakedown(let selfValue), 
                .toolsOzoneModerationDefsModEventTakedown(let otherValue)):
                return selfValue == otherValue
            case (.toolsOzoneModerationDefsModEventAcknowledge(let selfValue), 
                .toolsOzoneModerationDefsModEventAcknowledge(let otherValue)):
                return selfValue == otherValue
            case (.toolsOzoneModerationDefsModEventEscalate(let selfValue), 
                .toolsOzoneModerationDefsModEventEscalate(let otherValue)):
                return selfValue == otherValue
            case (.toolsOzoneModerationDefsModEventComment(let selfValue), 
                .toolsOzoneModerationDefsModEventComment(let otherValue)):
                return selfValue == otherValue
            case (.toolsOzoneModerationDefsModEventLabel(let selfValue), 
                .toolsOzoneModerationDefsModEventLabel(let otherValue)):
                return selfValue == otherValue
            case (.toolsOzoneModerationDefsModEventReport(let selfValue), 
                .toolsOzoneModerationDefsModEventReport(let otherValue)):
                return selfValue == otherValue
            case (.toolsOzoneModerationDefsModEventMute(let selfValue), 
                .toolsOzoneModerationDefsModEventMute(let otherValue)):
                return selfValue == otherValue
            case (.toolsOzoneModerationDefsModEventUnmute(let selfValue), 
                .toolsOzoneModerationDefsModEventUnmute(let otherValue)):
                return selfValue == otherValue
            case (.toolsOzoneModerationDefsModEventMuteReporter(let selfValue), 
                .toolsOzoneModerationDefsModEventMuteReporter(let otherValue)):
                return selfValue == otherValue
            case (.toolsOzoneModerationDefsModEventUnmuteReporter(let selfValue), 
                .toolsOzoneModerationDefsModEventUnmuteReporter(let otherValue)):
                return selfValue == otherValue
            case (.toolsOzoneModerationDefsModEventReverseTakedown(let selfValue), 
                .toolsOzoneModerationDefsModEventReverseTakedown(let otherValue)):
                return selfValue == otherValue
            case (.toolsOzoneModerationDefsModEventResolveAppeal(let selfValue), 
                .toolsOzoneModerationDefsModEventResolveAppeal(let otherValue)):
                return selfValue == otherValue
            case (.toolsOzoneModerationDefsModEventEmail(let selfValue), 
                .toolsOzoneModerationDefsModEventEmail(let otherValue)):
                return selfValue == otherValue
            case (.toolsOzoneModerationDefsModEventTag(let selfValue), 
                .toolsOzoneModerationDefsModEventTag(let otherValue)):
                return selfValue == otherValue
            case (.unexpected(let selfValue), .unexpected(let otherValue)):
                return selfValue.isEqual(to: otherValue)
            default:
                return false
        }
    }
}




public enum InputSubjectUnion: Codable, ATProtocolCodable, ATProtocolValue {
    case comAtprotoAdminDefsRepoRef(ComAtprotoAdminDefs.RepoRef)
    case comAtprotoRepoStrongRef(ComAtprotoRepoStrongRef)
    case unexpected(ATProtocolValueContainer)

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)

        switch typeValue {
        case "com.atproto.admin.defs#repoRef":
            let value = try ComAtprotoAdminDefs.RepoRef(from: decoder)
            self = .comAtprotoAdminDefsRepoRef(value)
        case "com.atproto.repo.strongRef":
            let value = try ComAtprotoRepoStrongRef(from: decoder)
            self = .comAtprotoRepoStrongRef(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .comAtprotoAdminDefsRepoRef(let value):
            try container.encode("com.atproto.admin.defs#repoRef", forKey: .type)
            try value.encode(to: encoder)
        case .comAtprotoRepoStrongRef(let value):
            try container.encode("com.atproto.repo.strongRef", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let ATProtocolValueContainer):
            try ATProtocolValueContainer.encode(to: encoder)
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .comAtprotoAdminDefsRepoRef(let value):
            hasher.combine("com.atproto.admin.defs#repoRef")
            hasher.combine(value)
        case .comAtprotoRepoStrongRef(let value):
            hasher.combine("com.atproto.repo.strongRef")
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
        guard let otherValue = other as? InputSubjectUnion else { return false }

        switch (self, otherValue) {
            case (.comAtprotoAdminDefsRepoRef(let selfValue), 
                .comAtprotoAdminDefsRepoRef(let otherValue)):
                return selfValue == otherValue
            case (.comAtprotoRepoStrongRef(let selfValue), 
                .comAtprotoRepoStrongRef(let otherValue)):
                return selfValue == otherValue
            case (.unexpected(let selfValue), .unexpected(let otherValue)):
                return selfValue.isEqual(to: otherValue)
            default:
                return false
        }
    }
}




public enum ToolsOzoneModerationEmitEventEventUnion: Codable, ATProtocolCodable, ATProtocolValue {
    case toolsOzoneModerationDefsModEventTakedown(ToolsOzoneModerationDefs.ModEventTakedown)
    case toolsOzoneModerationDefsModEventAcknowledge(ToolsOzoneModerationDefs.ModEventAcknowledge)
    case toolsOzoneModerationDefsModEventEscalate(ToolsOzoneModerationDefs.ModEventEscalate)
    case toolsOzoneModerationDefsModEventComment(ToolsOzoneModerationDefs.ModEventComment)
    case toolsOzoneModerationDefsModEventLabel(ToolsOzoneModerationDefs.ModEventLabel)
    case toolsOzoneModerationDefsModEventReport(ToolsOzoneModerationDefs.ModEventReport)
    case toolsOzoneModerationDefsModEventMute(ToolsOzoneModerationDefs.ModEventMute)
    case toolsOzoneModerationDefsModEventUnmute(ToolsOzoneModerationDefs.ModEventUnmute)
    case toolsOzoneModerationDefsModEventMuteReporter(ToolsOzoneModerationDefs.ModEventMuteReporter)
    case toolsOzoneModerationDefsModEventUnmuteReporter(ToolsOzoneModerationDefs.ModEventUnmuteReporter)
    case toolsOzoneModerationDefsModEventReverseTakedown(ToolsOzoneModerationDefs.ModEventReverseTakedown)
    case toolsOzoneModerationDefsModEventResolveAppeal(ToolsOzoneModerationDefs.ModEventResolveAppeal)
    case toolsOzoneModerationDefsModEventEmail(ToolsOzoneModerationDefs.ModEventEmail)
    case toolsOzoneModerationDefsModEventTag(ToolsOzoneModerationDefs.ModEventTag)
    case unexpected(ATProtocolValueContainer)

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)

        switch typeValue {
        case "tools.ozone.moderation.defs#modEventTakedown":
            let value = try ToolsOzoneModerationDefs.ModEventTakedown(from: decoder)
            self = .toolsOzoneModerationDefsModEventTakedown(value)
        case "tools.ozone.moderation.defs#modEventAcknowledge":
            let value = try ToolsOzoneModerationDefs.ModEventAcknowledge(from: decoder)
            self = .toolsOzoneModerationDefsModEventAcknowledge(value)
        case "tools.ozone.moderation.defs#modEventEscalate":
            let value = try ToolsOzoneModerationDefs.ModEventEscalate(from: decoder)
            self = .toolsOzoneModerationDefsModEventEscalate(value)
        case "tools.ozone.moderation.defs#modEventComment":
            let value = try ToolsOzoneModerationDefs.ModEventComment(from: decoder)
            self = .toolsOzoneModerationDefsModEventComment(value)
        case "tools.ozone.moderation.defs#modEventLabel":
            let value = try ToolsOzoneModerationDefs.ModEventLabel(from: decoder)
            self = .toolsOzoneModerationDefsModEventLabel(value)
        case "tools.ozone.moderation.defs#modEventReport":
            let value = try ToolsOzoneModerationDefs.ModEventReport(from: decoder)
            self = .toolsOzoneModerationDefsModEventReport(value)
        case "tools.ozone.moderation.defs#modEventMute":
            let value = try ToolsOzoneModerationDefs.ModEventMute(from: decoder)
            self = .toolsOzoneModerationDefsModEventMute(value)
        case "tools.ozone.moderation.defs#modEventUnmute":
            let value = try ToolsOzoneModerationDefs.ModEventUnmute(from: decoder)
            self = .toolsOzoneModerationDefsModEventUnmute(value)
        case "tools.ozone.moderation.defs#modEventMuteReporter":
            let value = try ToolsOzoneModerationDefs.ModEventMuteReporter(from: decoder)
            self = .toolsOzoneModerationDefsModEventMuteReporter(value)
        case "tools.ozone.moderation.defs#modEventUnmuteReporter":
            let value = try ToolsOzoneModerationDefs.ModEventUnmuteReporter(from: decoder)
            self = .toolsOzoneModerationDefsModEventUnmuteReporter(value)
        case "tools.ozone.moderation.defs#modEventReverseTakedown":
            let value = try ToolsOzoneModerationDefs.ModEventReverseTakedown(from: decoder)
            self = .toolsOzoneModerationDefsModEventReverseTakedown(value)
        case "tools.ozone.moderation.defs#modEventResolveAppeal":
            let value = try ToolsOzoneModerationDefs.ModEventResolveAppeal(from: decoder)
            self = .toolsOzoneModerationDefsModEventResolveAppeal(value)
        case "tools.ozone.moderation.defs#modEventEmail":
            let value = try ToolsOzoneModerationDefs.ModEventEmail(from: decoder)
            self = .toolsOzoneModerationDefsModEventEmail(value)
        case "tools.ozone.moderation.defs#modEventTag":
            let value = try ToolsOzoneModerationDefs.ModEventTag(from: decoder)
            self = .toolsOzoneModerationDefsModEventTag(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .toolsOzoneModerationDefsModEventTakedown(let value):
            try container.encode("tools.ozone.moderation.defs#modEventTakedown", forKey: .type)
            try value.encode(to: encoder)
        case .toolsOzoneModerationDefsModEventAcknowledge(let value):
            try container.encode("tools.ozone.moderation.defs#modEventAcknowledge", forKey: .type)
            try value.encode(to: encoder)
        case .toolsOzoneModerationDefsModEventEscalate(let value):
            try container.encode("tools.ozone.moderation.defs#modEventEscalate", forKey: .type)
            try value.encode(to: encoder)
        case .toolsOzoneModerationDefsModEventComment(let value):
            try container.encode("tools.ozone.moderation.defs#modEventComment", forKey: .type)
            try value.encode(to: encoder)
        case .toolsOzoneModerationDefsModEventLabel(let value):
            try container.encode("tools.ozone.moderation.defs#modEventLabel", forKey: .type)
            try value.encode(to: encoder)
        case .toolsOzoneModerationDefsModEventReport(let value):
            try container.encode("tools.ozone.moderation.defs#modEventReport", forKey: .type)
            try value.encode(to: encoder)
        case .toolsOzoneModerationDefsModEventMute(let value):
            try container.encode("tools.ozone.moderation.defs#modEventMute", forKey: .type)
            try value.encode(to: encoder)
        case .toolsOzoneModerationDefsModEventUnmute(let value):
            try container.encode("tools.ozone.moderation.defs#modEventUnmute", forKey: .type)
            try value.encode(to: encoder)
        case .toolsOzoneModerationDefsModEventMuteReporter(let value):
            try container.encode("tools.ozone.moderation.defs#modEventMuteReporter", forKey: .type)
            try value.encode(to: encoder)
        case .toolsOzoneModerationDefsModEventUnmuteReporter(let value):
            try container.encode("tools.ozone.moderation.defs#modEventUnmuteReporter", forKey: .type)
            try value.encode(to: encoder)
        case .toolsOzoneModerationDefsModEventReverseTakedown(let value):
            try container.encode("tools.ozone.moderation.defs#modEventReverseTakedown", forKey: .type)
            try value.encode(to: encoder)
        case .toolsOzoneModerationDefsModEventResolveAppeal(let value):
            try container.encode("tools.ozone.moderation.defs#modEventResolveAppeal", forKey: .type)
            try value.encode(to: encoder)
        case .toolsOzoneModerationDefsModEventEmail(let value):
            try container.encode("tools.ozone.moderation.defs#modEventEmail", forKey: .type)
            try value.encode(to: encoder)
        case .toolsOzoneModerationDefsModEventTag(let value):
            try container.encode("tools.ozone.moderation.defs#modEventTag", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let ATProtocolValueContainer):
            try ATProtocolValueContainer.encode(to: encoder)
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .toolsOzoneModerationDefsModEventTakedown(let value):
            hasher.combine("tools.ozone.moderation.defs#modEventTakedown")
            hasher.combine(value)
        case .toolsOzoneModerationDefsModEventAcknowledge(let value):
            hasher.combine("tools.ozone.moderation.defs#modEventAcknowledge")
            hasher.combine(value)
        case .toolsOzoneModerationDefsModEventEscalate(let value):
            hasher.combine("tools.ozone.moderation.defs#modEventEscalate")
            hasher.combine(value)
        case .toolsOzoneModerationDefsModEventComment(let value):
            hasher.combine("tools.ozone.moderation.defs#modEventComment")
            hasher.combine(value)
        case .toolsOzoneModerationDefsModEventLabel(let value):
            hasher.combine("tools.ozone.moderation.defs#modEventLabel")
            hasher.combine(value)
        case .toolsOzoneModerationDefsModEventReport(let value):
            hasher.combine("tools.ozone.moderation.defs#modEventReport")
            hasher.combine(value)
        case .toolsOzoneModerationDefsModEventMute(let value):
            hasher.combine("tools.ozone.moderation.defs#modEventMute")
            hasher.combine(value)
        case .toolsOzoneModerationDefsModEventUnmute(let value):
            hasher.combine("tools.ozone.moderation.defs#modEventUnmute")
            hasher.combine(value)
        case .toolsOzoneModerationDefsModEventMuteReporter(let value):
            hasher.combine("tools.ozone.moderation.defs#modEventMuteReporter")
            hasher.combine(value)
        case .toolsOzoneModerationDefsModEventUnmuteReporter(let value):
            hasher.combine("tools.ozone.moderation.defs#modEventUnmuteReporter")
            hasher.combine(value)
        case .toolsOzoneModerationDefsModEventReverseTakedown(let value):
            hasher.combine("tools.ozone.moderation.defs#modEventReverseTakedown")
            hasher.combine(value)
        case .toolsOzoneModerationDefsModEventResolveAppeal(let value):
            hasher.combine("tools.ozone.moderation.defs#modEventResolveAppeal")
            hasher.combine(value)
        case .toolsOzoneModerationDefsModEventEmail(let value):
            hasher.combine("tools.ozone.moderation.defs#modEventEmail")
            hasher.combine(value)
        case .toolsOzoneModerationDefsModEventTag(let value):
            hasher.combine("tools.ozone.moderation.defs#modEventTag")
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
        guard let otherValue = other as? ToolsOzoneModerationEmitEventEventUnion else { return false }

        switch (self, otherValue) {
            case (.toolsOzoneModerationDefsModEventTakedown(let selfValue), 
                .toolsOzoneModerationDefsModEventTakedown(let otherValue)):
                return selfValue == otherValue
            case (.toolsOzoneModerationDefsModEventAcknowledge(let selfValue), 
                .toolsOzoneModerationDefsModEventAcknowledge(let otherValue)):
                return selfValue == otherValue
            case (.toolsOzoneModerationDefsModEventEscalate(let selfValue), 
                .toolsOzoneModerationDefsModEventEscalate(let otherValue)):
                return selfValue == otherValue
            case (.toolsOzoneModerationDefsModEventComment(let selfValue), 
                .toolsOzoneModerationDefsModEventComment(let otherValue)):
                return selfValue == otherValue
            case (.toolsOzoneModerationDefsModEventLabel(let selfValue), 
                .toolsOzoneModerationDefsModEventLabel(let otherValue)):
                return selfValue == otherValue
            case (.toolsOzoneModerationDefsModEventReport(let selfValue), 
                .toolsOzoneModerationDefsModEventReport(let otherValue)):
                return selfValue == otherValue
            case (.toolsOzoneModerationDefsModEventMute(let selfValue), 
                .toolsOzoneModerationDefsModEventMute(let otherValue)):
                return selfValue == otherValue
            case (.toolsOzoneModerationDefsModEventUnmute(let selfValue), 
                .toolsOzoneModerationDefsModEventUnmute(let otherValue)):
                return selfValue == otherValue
            case (.toolsOzoneModerationDefsModEventMuteReporter(let selfValue), 
                .toolsOzoneModerationDefsModEventMuteReporter(let otherValue)):
                return selfValue == otherValue
            case (.toolsOzoneModerationDefsModEventUnmuteReporter(let selfValue), 
                .toolsOzoneModerationDefsModEventUnmuteReporter(let otherValue)):
                return selfValue == otherValue
            case (.toolsOzoneModerationDefsModEventReverseTakedown(let selfValue), 
                .toolsOzoneModerationDefsModEventReverseTakedown(let otherValue)):
                return selfValue == otherValue
            case (.toolsOzoneModerationDefsModEventResolveAppeal(let selfValue), 
                .toolsOzoneModerationDefsModEventResolveAppeal(let otherValue)):
                return selfValue == otherValue
            case (.toolsOzoneModerationDefsModEventEmail(let selfValue), 
                .toolsOzoneModerationDefsModEventEmail(let otherValue)):
                return selfValue == otherValue
            case (.toolsOzoneModerationDefsModEventTag(let selfValue), 
                .toolsOzoneModerationDefsModEventTag(let otherValue)):
                return selfValue == otherValue
            case (.unexpected(let selfValue), .unexpected(let otherValue)):
                return selfValue.isEqual(to: otherValue)
            default:
                return false
        }
    }
}




public enum ToolsOzoneModerationEmitEventSubjectUnion: Codable, ATProtocolCodable, ATProtocolValue {
    case comAtprotoAdminDefsRepoRef(ComAtprotoAdminDefs.RepoRef)
    case comAtprotoRepoStrongRef(ComAtprotoRepoStrongRef)
    case unexpected(ATProtocolValueContainer)

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)

        switch typeValue {
        case "com.atproto.admin.defs#repoRef":
            let value = try ComAtprotoAdminDefs.RepoRef(from: decoder)
            self = .comAtprotoAdminDefsRepoRef(value)
        case "com.atproto.repo.strongRef":
            let value = try ComAtprotoRepoStrongRef(from: decoder)
            self = .comAtprotoRepoStrongRef(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .comAtprotoAdminDefsRepoRef(let value):
            try container.encode("com.atproto.admin.defs#repoRef", forKey: .type)
            try value.encode(to: encoder)
        case .comAtprotoRepoStrongRef(let value):
            try container.encode("com.atproto.repo.strongRef", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let ATProtocolValueContainer):
            try ATProtocolValueContainer.encode(to: encoder)
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .comAtprotoAdminDefsRepoRef(let value):
            hasher.combine("com.atproto.admin.defs#repoRef")
            hasher.combine(value)
        case .comAtprotoRepoStrongRef(let value):
            hasher.combine("com.atproto.repo.strongRef")
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
        guard let otherValue = other as? ToolsOzoneModerationEmitEventSubjectUnion else { return false }

        switch (self, otherValue) {
            case (.comAtprotoAdminDefsRepoRef(let selfValue), 
                .comAtprotoAdminDefsRepoRef(let otherValue)):
                return selfValue == otherValue
            case (.comAtprotoRepoStrongRef(let selfValue), 
                .comAtprotoRepoStrongRef(let otherValue)):
                return selfValue == otherValue
            case (.unexpected(let selfValue), .unexpected(let otherValue)):
                return selfValue.isEqual(to: otherValue)
            default:
                return false
        }
    }
}


}

extension ATProtoClient.Tools.Ozone.Moderation {
    /// Take a moderation action on an actor.
    public func emitEvent(
        
        input: ToolsOzoneModerationEmitEvent.Input
        
    ) async throws -> (responseCode: Int, data: ToolsOzoneModerationEmitEvent.Output?) {
        let endpoint = "tools.ozone.moderation.emitEvent"
        
        var headers: [String: String] = [:]
        
        headers["Content-Type"] = "application/json"
        
        
        
        headers["Accept"] = "application/json"
        
        
        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers, 
            body: requestData,
            queryItems: nil
        )
        
        
        let (responseData, response) = try await networkManager.performRequest(urlRequest)
        let responseCode = response.statusCode

        // Content-Type validation
        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }
        
        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        // Data decoding and validation
        
        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(ToolsOzoneModerationEmitEvent.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
        
    }
    
}
                           
