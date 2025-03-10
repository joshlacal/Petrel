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
            return rawValue
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
        case toolsOzoneModerationDefsModEventDivert(ToolsOzoneModerationDefs.ModEventDivert)
        case toolsOzoneModerationDefsModEventTag(ToolsOzoneModerationDefs.ModEventTag)
        case toolsOzoneModerationDefsAccountEvent(ToolsOzoneModerationDefs.AccountEvent)
        case toolsOzoneModerationDefsIdentityEvent(ToolsOzoneModerationDefs.IdentityEvent)
        case toolsOzoneModerationDefsRecordEvent(ToolsOzoneModerationDefs.RecordEvent)
        case toolsOzoneModerationDefsModEventPriorityScore(ToolsOzoneModerationDefs.ModEventPriorityScore)
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
            case "tools.ozone.moderation.defs#modEventDivert":
                let value = try ToolsOzoneModerationDefs.ModEventDivert(from: decoder)
                self = .toolsOzoneModerationDefsModEventDivert(value)
            case "tools.ozone.moderation.defs#modEventTag":
                let value = try ToolsOzoneModerationDefs.ModEventTag(from: decoder)
                self = .toolsOzoneModerationDefsModEventTag(value)
            case "tools.ozone.moderation.defs#accountEvent":
                let value = try ToolsOzoneModerationDefs.AccountEvent(from: decoder)
                self = .toolsOzoneModerationDefsAccountEvent(value)
            case "tools.ozone.moderation.defs#identityEvent":
                let value = try ToolsOzoneModerationDefs.IdentityEvent(from: decoder)
                self = .toolsOzoneModerationDefsIdentityEvent(value)
            case "tools.ozone.moderation.defs#recordEvent":
                let value = try ToolsOzoneModerationDefs.RecordEvent(from: decoder)
                self = .toolsOzoneModerationDefsRecordEvent(value)
            case "tools.ozone.moderation.defs#modEventPriorityScore":
                let value = try ToolsOzoneModerationDefs.ModEventPriorityScore(from: decoder)
                self = .toolsOzoneModerationDefsModEventPriorityScore(value)
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .toolsOzoneModerationDefsModEventTakedown(value):
                try container.encode("tools.ozone.moderation.defs#modEventTakedown", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventAcknowledge(value):
                try container.encode("tools.ozone.moderation.defs#modEventAcknowledge", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventEscalate(value):
                try container.encode("tools.ozone.moderation.defs#modEventEscalate", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventComment(value):
                try container.encode("tools.ozone.moderation.defs#modEventComment", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventLabel(value):
                try container.encode("tools.ozone.moderation.defs#modEventLabel", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventReport(value):
                try container.encode("tools.ozone.moderation.defs#modEventReport", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventMute(value):
                try container.encode("tools.ozone.moderation.defs#modEventMute", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventUnmute(value):
                try container.encode("tools.ozone.moderation.defs#modEventUnmute", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventMuteReporter(value):
                try container.encode("tools.ozone.moderation.defs#modEventMuteReporter", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventUnmuteReporter(value):
                try container.encode("tools.ozone.moderation.defs#modEventUnmuteReporter", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventReverseTakedown(value):
                try container.encode("tools.ozone.moderation.defs#modEventReverseTakedown", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventResolveAppeal(value):
                try container.encode("tools.ozone.moderation.defs#modEventResolveAppeal", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventEmail(value):
                try container.encode("tools.ozone.moderation.defs#modEventEmail", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventDivert(value):
                try container.encode("tools.ozone.moderation.defs#modEventDivert", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventTag(value):
                try container.encode("tools.ozone.moderation.defs#modEventTag", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsAccountEvent(value):
                try container.encode("tools.ozone.moderation.defs#accountEvent", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsIdentityEvent(value):
                try container.encode("tools.ozone.moderation.defs#identityEvent", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsRecordEvent(value):
                try container.encode("tools.ozone.moderation.defs#recordEvent", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventPriorityScore(value):
                try container.encode("tools.ozone.moderation.defs#modEventPriorityScore", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(ATProtocolValueContainer):
                try ATProtocolValueContainer.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .toolsOzoneModerationDefsModEventTakedown(value):
                hasher.combine("tools.ozone.moderation.defs#modEventTakedown")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventAcknowledge(value):
                hasher.combine("tools.ozone.moderation.defs#modEventAcknowledge")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventEscalate(value):
                hasher.combine("tools.ozone.moderation.defs#modEventEscalate")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventComment(value):
                hasher.combine("tools.ozone.moderation.defs#modEventComment")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventLabel(value):
                hasher.combine("tools.ozone.moderation.defs#modEventLabel")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventReport(value):
                hasher.combine("tools.ozone.moderation.defs#modEventReport")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventMute(value):
                hasher.combine("tools.ozone.moderation.defs#modEventMute")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventUnmute(value):
                hasher.combine("tools.ozone.moderation.defs#modEventUnmute")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventMuteReporter(value):
                hasher.combine("tools.ozone.moderation.defs#modEventMuteReporter")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventUnmuteReporter(value):
                hasher.combine("tools.ozone.moderation.defs#modEventUnmuteReporter")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventReverseTakedown(value):
                hasher.combine("tools.ozone.moderation.defs#modEventReverseTakedown")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventResolveAppeal(value):
                hasher.combine("tools.ozone.moderation.defs#modEventResolveAppeal")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventEmail(value):
                hasher.combine("tools.ozone.moderation.defs#modEventEmail")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventDivert(value):
                hasher.combine("tools.ozone.moderation.defs#modEventDivert")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventTag(value):
                hasher.combine("tools.ozone.moderation.defs#modEventTag")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsAccountEvent(value):
                hasher.combine("tools.ozone.moderation.defs#accountEvent")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsIdentityEvent(value):
                hasher.combine("tools.ozone.moderation.defs#identityEvent")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsRecordEvent(value):
                hasher.combine("tools.ozone.moderation.defs#recordEvent")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventPriorityScore(value):
                hasher.combine("tools.ozone.moderation.defs#modEventPriorityScore")
                hasher.combine(value)
            case let .unexpected(ATProtocolValueContainer):
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
            case let (
                .toolsOzoneModerationDefsModEventTakedown(selfValue),
                .toolsOzoneModerationDefsModEventTakedown(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .toolsOzoneModerationDefsModEventAcknowledge(selfValue),
                .toolsOzoneModerationDefsModEventAcknowledge(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .toolsOzoneModerationDefsModEventEscalate(selfValue),
                .toolsOzoneModerationDefsModEventEscalate(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .toolsOzoneModerationDefsModEventComment(selfValue),
                .toolsOzoneModerationDefsModEventComment(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .toolsOzoneModerationDefsModEventLabel(selfValue),
                .toolsOzoneModerationDefsModEventLabel(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .toolsOzoneModerationDefsModEventReport(selfValue),
                .toolsOzoneModerationDefsModEventReport(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .toolsOzoneModerationDefsModEventMute(selfValue),
                .toolsOzoneModerationDefsModEventMute(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .toolsOzoneModerationDefsModEventUnmute(selfValue),
                .toolsOzoneModerationDefsModEventUnmute(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .toolsOzoneModerationDefsModEventMuteReporter(selfValue),
                .toolsOzoneModerationDefsModEventMuteReporter(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .toolsOzoneModerationDefsModEventUnmuteReporter(selfValue),
                .toolsOzoneModerationDefsModEventUnmuteReporter(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .toolsOzoneModerationDefsModEventReverseTakedown(selfValue),
                .toolsOzoneModerationDefsModEventReverseTakedown(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .toolsOzoneModerationDefsModEventResolveAppeal(selfValue),
                .toolsOzoneModerationDefsModEventResolveAppeal(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .toolsOzoneModerationDefsModEventEmail(selfValue),
                .toolsOzoneModerationDefsModEventEmail(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .toolsOzoneModerationDefsModEventDivert(selfValue),
                .toolsOzoneModerationDefsModEventDivert(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .toolsOzoneModerationDefsModEventTag(selfValue),
                .toolsOzoneModerationDefsModEventTag(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .toolsOzoneModerationDefsAccountEvent(selfValue),
                .toolsOzoneModerationDefsAccountEvent(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .toolsOzoneModerationDefsIdentityEvent(selfValue),
                .toolsOzoneModerationDefsIdentityEvent(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .toolsOzoneModerationDefsRecordEvent(selfValue),
                .toolsOzoneModerationDefsRecordEvent(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .toolsOzoneModerationDefsModEventPriorityScore(selfValue),
                .toolsOzoneModerationDefsModEventPriorityScore(otherValue)
            ):
                return selfValue == otherValue
            case let (.unexpected(selfValue), .unexpected(otherValue)):
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
            case let .comAtprotoAdminDefsRepoRef(value):
                try container.encode("com.atproto.admin.defs#repoRef", forKey: .type)
                try value.encode(to: encoder)
            case let .comAtprotoRepoStrongRef(value):
                try container.encode("com.atproto.repo.strongRef", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(ATProtocolValueContainer):
                try ATProtocolValueContainer.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .comAtprotoAdminDefsRepoRef(value):
                hasher.combine("com.atproto.admin.defs#repoRef")
                hasher.combine(value)
            case let .comAtprotoRepoStrongRef(value):
                hasher.combine("com.atproto.repo.strongRef")
                hasher.combine(value)
            case let .unexpected(ATProtocolValueContainer):
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
            case let (
                .comAtprotoAdminDefsRepoRef(selfValue),
                .comAtprotoAdminDefsRepoRef(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .comAtprotoRepoStrongRef(selfValue),
                .comAtprotoRepoStrongRef(otherValue)
            ):
                return selfValue == otherValue
            case let (.unexpected(selfValue), .unexpected(otherValue)):
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
        case toolsOzoneModerationDefsModEventDivert(ToolsOzoneModerationDefs.ModEventDivert)
        case toolsOzoneModerationDefsModEventTag(ToolsOzoneModerationDefs.ModEventTag)
        case toolsOzoneModerationDefsAccountEvent(ToolsOzoneModerationDefs.AccountEvent)
        case toolsOzoneModerationDefsIdentityEvent(ToolsOzoneModerationDefs.IdentityEvent)
        case toolsOzoneModerationDefsRecordEvent(ToolsOzoneModerationDefs.RecordEvent)
        case toolsOzoneModerationDefsModEventPriorityScore(ToolsOzoneModerationDefs.ModEventPriorityScore)
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
            case "tools.ozone.moderation.defs#modEventDivert":
                let value = try ToolsOzoneModerationDefs.ModEventDivert(from: decoder)
                self = .toolsOzoneModerationDefsModEventDivert(value)
            case "tools.ozone.moderation.defs#modEventTag":
                let value = try ToolsOzoneModerationDefs.ModEventTag(from: decoder)
                self = .toolsOzoneModerationDefsModEventTag(value)
            case "tools.ozone.moderation.defs#accountEvent":
                let value = try ToolsOzoneModerationDefs.AccountEvent(from: decoder)
                self = .toolsOzoneModerationDefsAccountEvent(value)
            case "tools.ozone.moderation.defs#identityEvent":
                let value = try ToolsOzoneModerationDefs.IdentityEvent(from: decoder)
                self = .toolsOzoneModerationDefsIdentityEvent(value)
            case "tools.ozone.moderation.defs#recordEvent":
                let value = try ToolsOzoneModerationDefs.RecordEvent(from: decoder)
                self = .toolsOzoneModerationDefsRecordEvent(value)
            case "tools.ozone.moderation.defs#modEventPriorityScore":
                let value = try ToolsOzoneModerationDefs.ModEventPriorityScore(from: decoder)
                self = .toolsOzoneModerationDefsModEventPriorityScore(value)
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .toolsOzoneModerationDefsModEventTakedown(value):
                try container.encode("tools.ozone.moderation.defs#modEventTakedown", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventAcknowledge(value):
                try container.encode("tools.ozone.moderation.defs#modEventAcknowledge", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventEscalate(value):
                try container.encode("tools.ozone.moderation.defs#modEventEscalate", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventComment(value):
                try container.encode("tools.ozone.moderation.defs#modEventComment", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventLabel(value):
                try container.encode("tools.ozone.moderation.defs#modEventLabel", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventReport(value):
                try container.encode("tools.ozone.moderation.defs#modEventReport", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventMute(value):
                try container.encode("tools.ozone.moderation.defs#modEventMute", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventUnmute(value):
                try container.encode("tools.ozone.moderation.defs#modEventUnmute", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventMuteReporter(value):
                try container.encode("tools.ozone.moderation.defs#modEventMuteReporter", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventUnmuteReporter(value):
                try container.encode("tools.ozone.moderation.defs#modEventUnmuteReporter", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventReverseTakedown(value):
                try container.encode("tools.ozone.moderation.defs#modEventReverseTakedown", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventResolveAppeal(value):
                try container.encode("tools.ozone.moderation.defs#modEventResolveAppeal", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventEmail(value):
                try container.encode("tools.ozone.moderation.defs#modEventEmail", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventDivert(value):
                try container.encode("tools.ozone.moderation.defs#modEventDivert", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventTag(value):
                try container.encode("tools.ozone.moderation.defs#modEventTag", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsAccountEvent(value):
                try container.encode("tools.ozone.moderation.defs#accountEvent", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsIdentityEvent(value):
                try container.encode("tools.ozone.moderation.defs#identityEvent", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsRecordEvent(value):
                try container.encode("tools.ozone.moderation.defs#recordEvent", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsModEventPriorityScore(value):
                try container.encode("tools.ozone.moderation.defs#modEventPriorityScore", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(ATProtocolValueContainer):
                try ATProtocolValueContainer.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .toolsOzoneModerationDefsModEventTakedown(value):
                hasher.combine("tools.ozone.moderation.defs#modEventTakedown")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventAcknowledge(value):
                hasher.combine("tools.ozone.moderation.defs#modEventAcknowledge")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventEscalate(value):
                hasher.combine("tools.ozone.moderation.defs#modEventEscalate")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventComment(value):
                hasher.combine("tools.ozone.moderation.defs#modEventComment")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventLabel(value):
                hasher.combine("tools.ozone.moderation.defs#modEventLabel")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventReport(value):
                hasher.combine("tools.ozone.moderation.defs#modEventReport")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventMute(value):
                hasher.combine("tools.ozone.moderation.defs#modEventMute")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventUnmute(value):
                hasher.combine("tools.ozone.moderation.defs#modEventUnmute")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventMuteReporter(value):
                hasher.combine("tools.ozone.moderation.defs#modEventMuteReporter")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventUnmuteReporter(value):
                hasher.combine("tools.ozone.moderation.defs#modEventUnmuteReporter")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventReverseTakedown(value):
                hasher.combine("tools.ozone.moderation.defs#modEventReverseTakedown")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventResolveAppeal(value):
                hasher.combine("tools.ozone.moderation.defs#modEventResolveAppeal")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventEmail(value):
                hasher.combine("tools.ozone.moderation.defs#modEventEmail")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventDivert(value):
                hasher.combine("tools.ozone.moderation.defs#modEventDivert")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventTag(value):
                hasher.combine("tools.ozone.moderation.defs#modEventTag")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsAccountEvent(value):
                hasher.combine("tools.ozone.moderation.defs#accountEvent")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsIdentityEvent(value):
                hasher.combine("tools.ozone.moderation.defs#identityEvent")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsRecordEvent(value):
                hasher.combine("tools.ozone.moderation.defs#recordEvent")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsModEventPriorityScore(value):
                hasher.combine("tools.ozone.moderation.defs#modEventPriorityScore")
                hasher.combine(value)
            case let .unexpected(ATProtocolValueContainer):
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
            case let (
                .toolsOzoneModerationDefsModEventTakedown(selfValue),
                .toolsOzoneModerationDefsModEventTakedown(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .toolsOzoneModerationDefsModEventAcknowledge(selfValue),
                .toolsOzoneModerationDefsModEventAcknowledge(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .toolsOzoneModerationDefsModEventEscalate(selfValue),
                .toolsOzoneModerationDefsModEventEscalate(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .toolsOzoneModerationDefsModEventComment(selfValue),
                .toolsOzoneModerationDefsModEventComment(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .toolsOzoneModerationDefsModEventLabel(selfValue),
                .toolsOzoneModerationDefsModEventLabel(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .toolsOzoneModerationDefsModEventReport(selfValue),
                .toolsOzoneModerationDefsModEventReport(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .toolsOzoneModerationDefsModEventMute(selfValue),
                .toolsOzoneModerationDefsModEventMute(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .toolsOzoneModerationDefsModEventUnmute(selfValue),
                .toolsOzoneModerationDefsModEventUnmute(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .toolsOzoneModerationDefsModEventMuteReporter(selfValue),
                .toolsOzoneModerationDefsModEventMuteReporter(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .toolsOzoneModerationDefsModEventUnmuteReporter(selfValue),
                .toolsOzoneModerationDefsModEventUnmuteReporter(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .toolsOzoneModerationDefsModEventReverseTakedown(selfValue),
                .toolsOzoneModerationDefsModEventReverseTakedown(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .toolsOzoneModerationDefsModEventResolveAppeal(selfValue),
                .toolsOzoneModerationDefsModEventResolveAppeal(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .toolsOzoneModerationDefsModEventEmail(selfValue),
                .toolsOzoneModerationDefsModEventEmail(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .toolsOzoneModerationDefsModEventDivert(selfValue),
                .toolsOzoneModerationDefsModEventDivert(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .toolsOzoneModerationDefsModEventTag(selfValue),
                .toolsOzoneModerationDefsModEventTag(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .toolsOzoneModerationDefsAccountEvent(selfValue),
                .toolsOzoneModerationDefsAccountEvent(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .toolsOzoneModerationDefsIdentityEvent(selfValue),
                .toolsOzoneModerationDefsIdentityEvent(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .toolsOzoneModerationDefsRecordEvent(selfValue),
                .toolsOzoneModerationDefsRecordEvent(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .toolsOzoneModerationDefsModEventPriorityScore(selfValue),
                .toolsOzoneModerationDefsModEventPriorityScore(otherValue)
            ):
                return selfValue == otherValue
            case let (.unexpected(selfValue), .unexpected(otherValue)):
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
            case let .comAtprotoAdminDefsRepoRef(value):
                try container.encode("com.atproto.admin.defs#repoRef", forKey: .type)
                try value.encode(to: encoder)
            case let .comAtprotoRepoStrongRef(value):
                try container.encode("com.atproto.repo.strongRef", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(ATProtocolValueContainer):
                try ATProtocolValueContainer.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .comAtprotoAdminDefsRepoRef(value):
                hasher.combine("com.atproto.admin.defs#repoRef")
                hasher.combine(value)
            case let .comAtprotoRepoStrongRef(value):
                hasher.combine("com.atproto.repo.strongRef")
                hasher.combine(value)
            case let .unexpected(ATProtocolValueContainer):
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
            case let (
                .comAtprotoAdminDefsRepoRef(selfValue),
                .comAtprotoAdminDefsRepoRef(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .comAtprotoRepoStrongRef(selfValue),
                .comAtprotoRepoStrongRef(otherValue)
            ):
                return selfValue == otherValue
            case let (.unexpected(selfValue), .unexpected(otherValue)):
                return selfValue.isEqual(to: otherValue)
            default:
                return false
            }
        }
    }
}

public extension ATProtoClient.Tools.Ozone.Moderation {
    /// Take a moderation action on an actor.
    func emitEvent(
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
