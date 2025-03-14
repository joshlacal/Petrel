import Foundation

// lexicon: 1, id: tools.ozone.moderation.emitEvent

public enum ToolsOzoneModerationEmitEvent {
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

    public enum InputEventUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, PendingDataLoadable, Equatable {
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
            case let .unexpected(container):
                try container.encode(to: encoder)
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
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: InputEventUnion, rhs: InputEventUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .toolsOzoneModerationDefsModEventTakedown(lhsValue),
                .toolsOzoneModerationDefsModEventTakedown(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventAcknowledge(lhsValue),
                .toolsOzoneModerationDefsModEventAcknowledge(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventEscalate(lhsValue),
                .toolsOzoneModerationDefsModEventEscalate(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventComment(lhsValue),
                .toolsOzoneModerationDefsModEventComment(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventLabel(lhsValue),
                .toolsOzoneModerationDefsModEventLabel(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventReport(lhsValue),
                .toolsOzoneModerationDefsModEventReport(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventMute(lhsValue),
                .toolsOzoneModerationDefsModEventMute(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventUnmute(lhsValue),
                .toolsOzoneModerationDefsModEventUnmute(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventMuteReporter(lhsValue),
                .toolsOzoneModerationDefsModEventMuteReporter(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventUnmuteReporter(lhsValue),
                .toolsOzoneModerationDefsModEventUnmuteReporter(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventReverseTakedown(lhsValue),
                .toolsOzoneModerationDefsModEventReverseTakedown(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventResolveAppeal(lhsValue),
                .toolsOzoneModerationDefsModEventResolveAppeal(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventEmail(lhsValue),
                .toolsOzoneModerationDefsModEventEmail(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventDivert(lhsValue),
                .toolsOzoneModerationDefsModEventDivert(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventTag(lhsValue),
                .toolsOzoneModerationDefsModEventTag(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsAccountEvent(lhsValue),
                .toolsOzoneModerationDefsAccountEvent(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsIdentityEvent(lhsValue),
                .toolsOzoneModerationDefsIdentityEvent(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsRecordEvent(lhsValue),
                .toolsOzoneModerationDefsRecordEvent(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventPriorityScore(lhsValue),
                .toolsOzoneModerationDefsModEventPriorityScore(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard other is InputEventUnion else { return false }
            return self == (other as! InputEventUnion)
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .toolsOzoneModerationDefsModEventTakedown(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventAcknowledge(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventEscalate(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventComment(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventLabel(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventReport(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventMute(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventUnmute(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventMuteReporter(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventUnmuteReporter(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventReverseTakedown(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventResolveAppeal(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventEmail(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventDivert(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventTag(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsAccountEvent(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsIdentityEvent(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsRecordEvent(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventPriorityScore(value):
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
            case let .toolsOzoneModerationDefsModEventTakedown(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ToolsOzoneModerationDefs.ModEventTakedown.self, from: jsonData)
                    {
                        self = .toolsOzoneModerationDefsModEventTakedown(decodedValue)
                    }
                }
            case let .toolsOzoneModerationDefsModEventAcknowledge(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ToolsOzoneModerationDefs.ModEventAcknowledge.self, from: jsonData)
                    {
                        self = .toolsOzoneModerationDefsModEventAcknowledge(decodedValue)
                    }
                }
            case let .toolsOzoneModerationDefsModEventEscalate(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ToolsOzoneModerationDefs.ModEventEscalate.self, from: jsonData)
                    {
                        self = .toolsOzoneModerationDefsModEventEscalate(decodedValue)
                    }
                }
            case let .toolsOzoneModerationDefsModEventComment(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ToolsOzoneModerationDefs.ModEventComment.self, from: jsonData)
                    {
                        self = .toolsOzoneModerationDefsModEventComment(decodedValue)
                    }
                }
            case let .toolsOzoneModerationDefsModEventLabel(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ToolsOzoneModerationDefs.ModEventLabel.self, from: jsonData)
                    {
                        self = .toolsOzoneModerationDefsModEventLabel(decodedValue)
                    }
                }
            case let .toolsOzoneModerationDefsModEventReport(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ToolsOzoneModerationDefs.ModEventReport.self, from: jsonData)
                    {
                        self = .toolsOzoneModerationDefsModEventReport(decodedValue)
                    }
                }
            case let .toolsOzoneModerationDefsModEventMute(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ToolsOzoneModerationDefs.ModEventMute.self, from: jsonData)
                    {
                        self = .toolsOzoneModerationDefsModEventMute(decodedValue)
                    }
                }
            case let .toolsOzoneModerationDefsModEventUnmute(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ToolsOzoneModerationDefs.ModEventUnmute.self, from: jsonData)
                    {
                        self = .toolsOzoneModerationDefsModEventUnmute(decodedValue)
                    }
                }
            case let .toolsOzoneModerationDefsModEventMuteReporter(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ToolsOzoneModerationDefs.ModEventMuteReporter.self, from: jsonData)
                    {
                        self = .toolsOzoneModerationDefsModEventMuteReporter(decodedValue)
                    }
                }
            case let .toolsOzoneModerationDefsModEventUnmuteReporter(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ToolsOzoneModerationDefs.ModEventUnmuteReporter.self, from: jsonData)
                    {
                        self = .toolsOzoneModerationDefsModEventUnmuteReporter(decodedValue)
                    }
                }
            case let .toolsOzoneModerationDefsModEventReverseTakedown(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ToolsOzoneModerationDefs.ModEventReverseTakedown.self, from: jsonData)
                    {
                        self = .toolsOzoneModerationDefsModEventReverseTakedown(decodedValue)
                    }
                }
            case let .toolsOzoneModerationDefsModEventResolveAppeal(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ToolsOzoneModerationDefs.ModEventResolveAppeal.self, from: jsonData)
                    {
                        self = .toolsOzoneModerationDefsModEventResolveAppeal(decodedValue)
                    }
                }
            case let .toolsOzoneModerationDefsModEventEmail(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ToolsOzoneModerationDefs.ModEventEmail.self, from: jsonData)
                    {
                        self = .toolsOzoneModerationDefsModEventEmail(decodedValue)
                    }
                }
            case let .toolsOzoneModerationDefsModEventDivert(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ToolsOzoneModerationDefs.ModEventDivert.self, from: jsonData)
                    {
                        self = .toolsOzoneModerationDefsModEventDivert(decodedValue)
                    }
                }
            case let .toolsOzoneModerationDefsModEventTag(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ToolsOzoneModerationDefs.ModEventTag.self, from: jsonData)
                    {
                        self = .toolsOzoneModerationDefsModEventTag(decodedValue)
                    }
                }
            case let .toolsOzoneModerationDefsAccountEvent(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ToolsOzoneModerationDefs.AccountEvent.self, from: jsonData)
                    {
                        self = .toolsOzoneModerationDefsAccountEvent(decodedValue)
                    }
                }
            case let .toolsOzoneModerationDefsIdentityEvent(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ToolsOzoneModerationDefs.IdentityEvent.self, from: jsonData)
                    {
                        self = .toolsOzoneModerationDefsIdentityEvent(decodedValue)
                    }
                }
            case let .toolsOzoneModerationDefsRecordEvent(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ToolsOzoneModerationDefs.RecordEvent.self, from: jsonData)
                    {
                        self = .toolsOzoneModerationDefsRecordEvent(decodedValue)
                    }
                }
            case let .toolsOzoneModerationDefsModEventPriorityScore(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ToolsOzoneModerationDefs.ModEventPriorityScore.self, from: jsonData)
                    {
                        self = .toolsOzoneModerationDefsModEventPriorityScore(decodedValue)
                    }
                }
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }

    public enum InputSubjectUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, PendingDataLoadable, Equatable {
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
            case let .unexpected(container):
                try container.encode(to: encoder)
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
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: InputSubjectUnion, rhs: InputSubjectUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .comAtprotoAdminDefsRepoRef(lhsValue),
                .comAtprotoAdminDefsRepoRef(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .comAtprotoRepoStrongRef(lhsValue),
                .comAtprotoRepoStrongRef(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard other is InputSubjectUnion else { return false }
            return self == (other as! InputSubjectUnion)
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .comAtprotoAdminDefsRepoRef(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .comAtprotoRepoStrongRef(value):
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
            case let .comAtprotoAdminDefsRepoRef(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ComAtprotoAdminDefs.RepoRef.self, from: jsonData)
                    {
                        self = .comAtprotoAdminDefsRepoRef(decodedValue)
                    }
                }
            case let .comAtprotoRepoStrongRef(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ComAtprotoRepoStrongRef.self, from: jsonData)
                    {
                        self = .comAtprotoRepoStrongRef(decodedValue)
                    }
                }
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }

    public enum ToolsOzoneModerationEmitEventEventUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, PendingDataLoadable, Equatable {
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
            case let .unexpected(container):
                try container.encode(to: encoder)
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
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: ToolsOzoneModerationEmitEventEventUnion, rhs: ToolsOzoneModerationEmitEventEventUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .toolsOzoneModerationDefsModEventTakedown(lhsValue),
                .toolsOzoneModerationDefsModEventTakedown(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventAcknowledge(lhsValue),
                .toolsOzoneModerationDefsModEventAcknowledge(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventEscalate(lhsValue),
                .toolsOzoneModerationDefsModEventEscalate(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventComment(lhsValue),
                .toolsOzoneModerationDefsModEventComment(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventLabel(lhsValue),
                .toolsOzoneModerationDefsModEventLabel(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventReport(lhsValue),
                .toolsOzoneModerationDefsModEventReport(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventMute(lhsValue),
                .toolsOzoneModerationDefsModEventMute(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventUnmute(lhsValue),
                .toolsOzoneModerationDefsModEventUnmute(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventMuteReporter(lhsValue),
                .toolsOzoneModerationDefsModEventMuteReporter(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventUnmuteReporter(lhsValue),
                .toolsOzoneModerationDefsModEventUnmuteReporter(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventReverseTakedown(lhsValue),
                .toolsOzoneModerationDefsModEventReverseTakedown(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventResolveAppeal(lhsValue),
                .toolsOzoneModerationDefsModEventResolveAppeal(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventEmail(lhsValue),
                .toolsOzoneModerationDefsModEventEmail(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventDivert(lhsValue),
                .toolsOzoneModerationDefsModEventDivert(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventTag(lhsValue),
                .toolsOzoneModerationDefsModEventTag(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsAccountEvent(lhsValue),
                .toolsOzoneModerationDefsAccountEvent(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsIdentityEvent(lhsValue),
                .toolsOzoneModerationDefsIdentityEvent(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsRecordEvent(lhsValue),
                .toolsOzoneModerationDefsRecordEvent(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsModEventPriorityScore(lhsValue),
                .toolsOzoneModerationDefsModEventPriorityScore(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard other is ToolsOzoneModerationEmitEventEventUnion else { return false }
            return self == (other as! ToolsOzoneModerationEmitEventEventUnion)
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .toolsOzoneModerationDefsModEventTakedown(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventAcknowledge(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventEscalate(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventComment(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventLabel(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventReport(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventMute(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventUnmute(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventMuteReporter(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventUnmuteReporter(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventReverseTakedown(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventResolveAppeal(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventEmail(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventDivert(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventTag(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsAccountEvent(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsIdentityEvent(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsRecordEvent(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .toolsOzoneModerationDefsModEventPriorityScore(value):
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
            case let .toolsOzoneModerationDefsModEventTakedown(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ToolsOzoneModerationDefs.ModEventTakedown.self, from: jsonData)
                    {
                        self = .toolsOzoneModerationDefsModEventTakedown(decodedValue)
                    }
                }
            case let .toolsOzoneModerationDefsModEventAcknowledge(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ToolsOzoneModerationDefs.ModEventAcknowledge.self, from: jsonData)
                    {
                        self = .toolsOzoneModerationDefsModEventAcknowledge(decodedValue)
                    }
                }
            case let .toolsOzoneModerationDefsModEventEscalate(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ToolsOzoneModerationDefs.ModEventEscalate.self, from: jsonData)
                    {
                        self = .toolsOzoneModerationDefsModEventEscalate(decodedValue)
                    }
                }
            case let .toolsOzoneModerationDefsModEventComment(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ToolsOzoneModerationDefs.ModEventComment.self, from: jsonData)
                    {
                        self = .toolsOzoneModerationDefsModEventComment(decodedValue)
                    }
                }
            case let .toolsOzoneModerationDefsModEventLabel(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ToolsOzoneModerationDefs.ModEventLabel.self, from: jsonData)
                    {
                        self = .toolsOzoneModerationDefsModEventLabel(decodedValue)
                    }
                }
            case let .toolsOzoneModerationDefsModEventReport(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ToolsOzoneModerationDefs.ModEventReport.self, from: jsonData)
                    {
                        self = .toolsOzoneModerationDefsModEventReport(decodedValue)
                    }
                }
            case let .toolsOzoneModerationDefsModEventMute(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ToolsOzoneModerationDefs.ModEventMute.self, from: jsonData)
                    {
                        self = .toolsOzoneModerationDefsModEventMute(decodedValue)
                    }
                }
            case let .toolsOzoneModerationDefsModEventUnmute(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ToolsOzoneModerationDefs.ModEventUnmute.self, from: jsonData)
                    {
                        self = .toolsOzoneModerationDefsModEventUnmute(decodedValue)
                    }
                }
            case let .toolsOzoneModerationDefsModEventMuteReporter(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ToolsOzoneModerationDefs.ModEventMuteReporter.self, from: jsonData)
                    {
                        self = .toolsOzoneModerationDefsModEventMuteReporter(decodedValue)
                    }
                }
            case let .toolsOzoneModerationDefsModEventUnmuteReporter(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ToolsOzoneModerationDefs.ModEventUnmuteReporter.self, from: jsonData)
                    {
                        self = .toolsOzoneModerationDefsModEventUnmuteReporter(decodedValue)
                    }
                }
            case let .toolsOzoneModerationDefsModEventReverseTakedown(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ToolsOzoneModerationDefs.ModEventReverseTakedown.self, from: jsonData)
                    {
                        self = .toolsOzoneModerationDefsModEventReverseTakedown(decodedValue)
                    }
                }
            case let .toolsOzoneModerationDefsModEventResolveAppeal(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ToolsOzoneModerationDefs.ModEventResolveAppeal.self, from: jsonData)
                    {
                        self = .toolsOzoneModerationDefsModEventResolveAppeal(decodedValue)
                    }
                }
            case let .toolsOzoneModerationDefsModEventEmail(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ToolsOzoneModerationDefs.ModEventEmail.self, from: jsonData)
                    {
                        self = .toolsOzoneModerationDefsModEventEmail(decodedValue)
                    }
                }
            case let .toolsOzoneModerationDefsModEventDivert(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ToolsOzoneModerationDefs.ModEventDivert.self, from: jsonData)
                    {
                        self = .toolsOzoneModerationDefsModEventDivert(decodedValue)
                    }
                }
            case let .toolsOzoneModerationDefsModEventTag(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ToolsOzoneModerationDefs.ModEventTag.self, from: jsonData)
                    {
                        self = .toolsOzoneModerationDefsModEventTag(decodedValue)
                    }
                }
            case let .toolsOzoneModerationDefsAccountEvent(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ToolsOzoneModerationDefs.AccountEvent.self, from: jsonData)
                    {
                        self = .toolsOzoneModerationDefsAccountEvent(decodedValue)
                    }
                }
            case let .toolsOzoneModerationDefsIdentityEvent(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ToolsOzoneModerationDefs.IdentityEvent.self, from: jsonData)
                    {
                        self = .toolsOzoneModerationDefsIdentityEvent(decodedValue)
                    }
                }
            case let .toolsOzoneModerationDefsRecordEvent(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ToolsOzoneModerationDefs.RecordEvent.self, from: jsonData)
                    {
                        self = .toolsOzoneModerationDefsRecordEvent(decodedValue)
                    }
                }
            case let .toolsOzoneModerationDefsModEventPriorityScore(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ToolsOzoneModerationDefs.ModEventPriorityScore.self, from: jsonData)
                    {
                        self = .toolsOzoneModerationDefsModEventPriorityScore(decodedValue)
                    }
                }
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }

    public enum ToolsOzoneModerationEmitEventSubjectUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, PendingDataLoadable, Equatable {
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
            case let .unexpected(container):
                try container.encode(to: encoder)
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
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: ToolsOzoneModerationEmitEventSubjectUnion, rhs: ToolsOzoneModerationEmitEventSubjectUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .comAtprotoAdminDefsRepoRef(lhsValue),
                .comAtprotoAdminDefsRepoRef(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .comAtprotoRepoStrongRef(lhsValue),
                .comAtprotoRepoStrongRef(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard other is ToolsOzoneModerationEmitEventSubjectUnion else { return false }
            return self == (other as! ToolsOzoneModerationEmitEventSubjectUnion)
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .comAtprotoAdminDefsRepoRef(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .comAtprotoRepoStrongRef(value):
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
            case let .comAtprotoAdminDefsRepoRef(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ComAtprotoAdminDefs.RepoRef.self, from: jsonData)
                    {
                        self = .comAtprotoAdminDefsRepoRef(decodedValue)
                    }
                }
            case let .comAtprotoRepoStrongRef(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ComAtprotoRepoStrongRef.self, from: jsonData)
                    {
                        self = .comAtprotoRepoStrongRef(decodedValue)
                    }
                }
            case .unexpected:
                // Nothing to load for unexpected values
                break
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

        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(ToolsOzoneModerationEmitEvent.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
