import Foundation

// lexicon: 1, id: tools.ozone.moderation.emitEvent

public enum ToolsOzoneModerationEmitEvent {
    public static let typeIdentifier = "tools.ozone.moderation.emitEvent"
    public struct Input: ATProtocolCodable {
        public let event: InputEventUnion
        public let subject: InputSubjectUnion
        public let subjectBlobCids: [CID]?
        public let createdBy: DID

        // Standard public initializer
        public init(event: InputEventUnion, subject: InputSubjectUnion, subjectBlobCids: [CID]? = nil, createdBy: DID) {
            self.event = event
            self.subject = subject
            self.subjectBlobCids = subjectBlobCids
            self.createdBy = createdBy
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            event = try container.decode(InputEventUnion.self, forKey: .event)

            subject = try container.decode(InputSubjectUnion.self, forKey: .subject)

            subjectBlobCids = try container.decodeIfPresent([CID].self, forKey: .subjectBlobCids)

            createdBy = try container.decode(DID.self, forKey: .createdBy)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(event, forKey: .event)

            try container.encode(subject, forKey: .subject)

            if let value = subjectBlobCids {
                if !value.isEmpty {
                    try container.encode(value, forKey: .subjectBlobCids)
                }
            }

            try container.encode(createdBy, forKey: .createdBy)
        }

        private enum CodingKeys: String, CodingKey {
            case event
            case subject
            case subjectBlobCids
            case createdBy
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Add fields in lexicon-defined order

            let eventValue = try (event as? DAGCBOREncodable)?.toCBORValue() ?? event
            map = map.adding(key: "event", value: eventValue)

            let subjectValue = try (subject as? DAGCBOREncodable)?.toCBORValue() ?? subject
            map = map.adding(key: "subject", value: subjectValue)

            if let value = subjectBlobCids {
                if !value.isEmpty {
                    let subjectBlobCidsValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                    map = map.adding(key: "subjectBlobCids", value: subjectBlobCidsValue)
                }
            }

            let createdByValue = try (createdBy as? DAGCBOREncodable)?.toCBORValue() ?? createdBy
            map = map.adding(key: "createdBy", value: createdByValue)

            return map
        }
    }

    public typealias Output = ToolsOzoneModerationDefs.ModEventView

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case subjectHasAction = "SubjectHasAction."
        public var description: String {
            return rawValue
        }
    }

    public enum InputEventUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
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

        public init(_ value: ToolsOzoneModerationDefs.ModEventTakedown) {
            self = .toolsOzoneModerationDefsModEventTakedown(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventAcknowledge) {
            self = .toolsOzoneModerationDefsModEventAcknowledge(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventEscalate) {
            self = .toolsOzoneModerationDefsModEventEscalate(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventComment) {
            self = .toolsOzoneModerationDefsModEventComment(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventLabel) {
            self = .toolsOzoneModerationDefsModEventLabel(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventReport) {
            self = .toolsOzoneModerationDefsModEventReport(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventMute) {
            self = .toolsOzoneModerationDefsModEventMute(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventUnmute) {
            self = .toolsOzoneModerationDefsModEventUnmute(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventMuteReporter) {
            self = .toolsOzoneModerationDefsModEventMuteReporter(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventUnmuteReporter) {
            self = .toolsOzoneModerationDefsModEventUnmuteReporter(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventReverseTakedown) {
            self = .toolsOzoneModerationDefsModEventReverseTakedown(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventResolveAppeal) {
            self = .toolsOzoneModerationDefsModEventResolveAppeal(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventEmail) {
            self = .toolsOzoneModerationDefsModEventEmail(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventDivert) {
            self = .toolsOzoneModerationDefsModEventDivert(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventTag) {
            self = .toolsOzoneModerationDefsModEventTag(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.AccountEvent) {
            self = .toolsOzoneModerationDefsAccountEvent(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.IdentityEvent) {
            self = .toolsOzoneModerationDefsIdentityEvent(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.RecordEvent) {
            self = .toolsOzoneModerationDefsRecordEvent(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventPriorityScore) {
            self = .toolsOzoneModerationDefsModEventPriorityScore(value)
        }

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
            guard let other = other as? InputEventUnion else { return false }
            return self == other
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .toolsOzoneModerationDefsModEventTakedown(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventTakedown")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .toolsOzoneModerationDefsModEventAcknowledge(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventAcknowledge")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .toolsOzoneModerationDefsModEventEscalate(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventEscalate")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .toolsOzoneModerationDefsModEventComment(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventComment")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .toolsOzoneModerationDefsModEventLabel(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventLabel")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .toolsOzoneModerationDefsModEventReport(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventReport")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .toolsOzoneModerationDefsModEventMute(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventMute")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .toolsOzoneModerationDefsModEventUnmute(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventUnmute")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .toolsOzoneModerationDefsModEventMuteReporter(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventMuteReporter")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .toolsOzoneModerationDefsModEventUnmuteReporter(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventUnmuteReporter")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .toolsOzoneModerationDefsModEventReverseTakedown(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventReverseTakedown")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .toolsOzoneModerationDefsModEventResolveAppeal(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventResolveAppeal")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .toolsOzoneModerationDefsModEventEmail(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventEmail")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .toolsOzoneModerationDefsModEventDivert(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventDivert")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .toolsOzoneModerationDefsModEventTag(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventTag")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .toolsOzoneModerationDefsAccountEvent(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#accountEvent")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .toolsOzoneModerationDefsIdentityEvent(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#identityEvent")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .toolsOzoneModerationDefsRecordEvent(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#recordEvent")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .toolsOzoneModerationDefsModEventPriorityScore(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventPriorityScore")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .toolsOzoneModerationDefsModEventTakedown(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventAcknowledge(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventEscalate(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventComment(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventLabel(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventReport(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventMute(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventUnmute(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventMuteReporter(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventUnmuteReporter(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventReverseTakedown(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventResolveAppeal(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventEmail(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventDivert(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventTag(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsAccountEvent(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsIdentityEvent(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsRecordEvent(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventPriorityScore(value):
                return value.hasPendingData
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .toolsOzoneModerationDefsModEventTakedown(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventTakedown(value)
            case var .toolsOzoneModerationDefsModEventAcknowledge(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventAcknowledge(value)
            case var .toolsOzoneModerationDefsModEventEscalate(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventEscalate(value)
            case var .toolsOzoneModerationDefsModEventComment(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventComment(value)
            case var .toolsOzoneModerationDefsModEventLabel(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventLabel(value)
            case var .toolsOzoneModerationDefsModEventReport(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventReport(value)
            case var .toolsOzoneModerationDefsModEventMute(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventMute(value)
            case var .toolsOzoneModerationDefsModEventUnmute(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventUnmute(value)
            case var .toolsOzoneModerationDefsModEventMuteReporter(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventMuteReporter(value)
            case var .toolsOzoneModerationDefsModEventUnmuteReporter(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventUnmuteReporter(value)
            case var .toolsOzoneModerationDefsModEventReverseTakedown(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventReverseTakedown(value)
            case var .toolsOzoneModerationDefsModEventResolveAppeal(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventResolveAppeal(value)
            case var .toolsOzoneModerationDefsModEventEmail(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventEmail(value)
            case var .toolsOzoneModerationDefsModEventDivert(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventDivert(value)
            case var .toolsOzoneModerationDefsModEventTag(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventTag(value)
            case var .toolsOzoneModerationDefsAccountEvent(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsAccountEvent(value)
            case var .toolsOzoneModerationDefsIdentityEvent(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsIdentityEvent(value)
            case var .toolsOzoneModerationDefsRecordEvent(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsRecordEvent(value)
            case var .toolsOzoneModerationDefsModEventPriorityScore(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventPriorityScore(value)
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }

    public enum InputSubjectUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case comAtprotoAdminDefsRepoRef(ComAtprotoAdminDefs.RepoRef)
        case comAtprotoRepoStrongRef(ComAtprotoRepoStrongRef)
        case unexpected(ATProtocolValueContainer)

        public init(_ value: ComAtprotoAdminDefs.RepoRef) {
            self = .comAtprotoAdminDefsRepoRef(value)
        }

        public init(_ value: ComAtprotoRepoStrongRef) {
            self = .comAtprotoRepoStrongRef(value)
        }

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
            guard let other = other as? InputSubjectUnion else { return false }
            return self == other
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .comAtprotoAdminDefsRepoRef(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "com.atproto.admin.defs#repoRef")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .comAtprotoRepoStrongRef(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "com.atproto.repo.strongRef")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .comAtprotoAdminDefsRepoRef(value):
                return value.hasPendingData
            case let .comAtprotoRepoStrongRef(value):
                return value.hasPendingData
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .comAtprotoAdminDefsRepoRef(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .comAtprotoAdminDefsRepoRef(value)
            case var .comAtprotoRepoStrongRef(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .comAtprotoRepoStrongRef(value)
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }

    public enum ToolsOzoneModerationEmitEventEventUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
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

        public init(_ value: ToolsOzoneModerationDefs.ModEventTakedown) {
            self = .toolsOzoneModerationDefsModEventTakedown(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventAcknowledge) {
            self = .toolsOzoneModerationDefsModEventAcknowledge(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventEscalate) {
            self = .toolsOzoneModerationDefsModEventEscalate(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventComment) {
            self = .toolsOzoneModerationDefsModEventComment(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventLabel) {
            self = .toolsOzoneModerationDefsModEventLabel(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventReport) {
            self = .toolsOzoneModerationDefsModEventReport(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventMute) {
            self = .toolsOzoneModerationDefsModEventMute(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventUnmute) {
            self = .toolsOzoneModerationDefsModEventUnmute(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventMuteReporter) {
            self = .toolsOzoneModerationDefsModEventMuteReporter(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventUnmuteReporter) {
            self = .toolsOzoneModerationDefsModEventUnmuteReporter(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventReverseTakedown) {
            self = .toolsOzoneModerationDefsModEventReverseTakedown(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventResolveAppeal) {
            self = .toolsOzoneModerationDefsModEventResolveAppeal(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventEmail) {
            self = .toolsOzoneModerationDefsModEventEmail(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventDivert) {
            self = .toolsOzoneModerationDefsModEventDivert(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventTag) {
            self = .toolsOzoneModerationDefsModEventTag(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.AccountEvent) {
            self = .toolsOzoneModerationDefsAccountEvent(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.IdentityEvent) {
            self = .toolsOzoneModerationDefsIdentityEvent(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.RecordEvent) {
            self = .toolsOzoneModerationDefsRecordEvent(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.ModEventPriorityScore) {
            self = .toolsOzoneModerationDefsModEventPriorityScore(value)
        }

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
            guard let other = other as? ToolsOzoneModerationEmitEventEventUnion else { return false }
            return self == other
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .toolsOzoneModerationDefsModEventTakedown(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventTakedown")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .toolsOzoneModerationDefsModEventAcknowledge(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventAcknowledge")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .toolsOzoneModerationDefsModEventEscalate(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventEscalate")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .toolsOzoneModerationDefsModEventComment(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventComment")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .toolsOzoneModerationDefsModEventLabel(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventLabel")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .toolsOzoneModerationDefsModEventReport(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventReport")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .toolsOzoneModerationDefsModEventMute(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventMute")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .toolsOzoneModerationDefsModEventUnmute(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventUnmute")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .toolsOzoneModerationDefsModEventMuteReporter(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventMuteReporter")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .toolsOzoneModerationDefsModEventUnmuteReporter(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventUnmuteReporter")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .toolsOzoneModerationDefsModEventReverseTakedown(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventReverseTakedown")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .toolsOzoneModerationDefsModEventResolveAppeal(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventResolveAppeal")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .toolsOzoneModerationDefsModEventEmail(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventEmail")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .toolsOzoneModerationDefsModEventDivert(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventDivert")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .toolsOzoneModerationDefsModEventTag(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventTag")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .toolsOzoneModerationDefsAccountEvent(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#accountEvent")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .toolsOzoneModerationDefsIdentityEvent(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#identityEvent")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .toolsOzoneModerationDefsRecordEvent(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#recordEvent")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .toolsOzoneModerationDefsModEventPriorityScore(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#modEventPriorityScore")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .toolsOzoneModerationDefsModEventTakedown(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventAcknowledge(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventEscalate(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventComment(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventLabel(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventReport(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventMute(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventUnmute(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventMuteReporter(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventUnmuteReporter(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventReverseTakedown(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventResolveAppeal(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventEmail(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventDivert(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventTag(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsAccountEvent(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsIdentityEvent(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsRecordEvent(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsModEventPriorityScore(value):
                return value.hasPendingData
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .toolsOzoneModerationDefsModEventTakedown(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventTakedown(value)
            case var .toolsOzoneModerationDefsModEventAcknowledge(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventAcknowledge(value)
            case var .toolsOzoneModerationDefsModEventEscalate(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventEscalate(value)
            case var .toolsOzoneModerationDefsModEventComment(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventComment(value)
            case var .toolsOzoneModerationDefsModEventLabel(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventLabel(value)
            case var .toolsOzoneModerationDefsModEventReport(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventReport(value)
            case var .toolsOzoneModerationDefsModEventMute(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventMute(value)
            case var .toolsOzoneModerationDefsModEventUnmute(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventUnmute(value)
            case var .toolsOzoneModerationDefsModEventMuteReporter(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventMuteReporter(value)
            case var .toolsOzoneModerationDefsModEventUnmuteReporter(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventUnmuteReporter(value)
            case var .toolsOzoneModerationDefsModEventReverseTakedown(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventReverseTakedown(value)
            case var .toolsOzoneModerationDefsModEventResolveAppeal(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventResolveAppeal(value)
            case var .toolsOzoneModerationDefsModEventEmail(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventEmail(value)
            case var .toolsOzoneModerationDefsModEventDivert(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventDivert(value)
            case var .toolsOzoneModerationDefsModEventTag(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventTag(value)
            case var .toolsOzoneModerationDefsAccountEvent(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsAccountEvent(value)
            case var .toolsOzoneModerationDefsIdentityEvent(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsIdentityEvent(value)
            case var .toolsOzoneModerationDefsRecordEvent(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsRecordEvent(value)
            case var .toolsOzoneModerationDefsModEventPriorityScore(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsModEventPriorityScore(value)
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }

    public enum ToolsOzoneModerationEmitEventSubjectUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case comAtprotoAdminDefsRepoRef(ComAtprotoAdminDefs.RepoRef)
        case comAtprotoRepoStrongRef(ComAtprotoRepoStrongRef)
        case unexpected(ATProtocolValueContainer)

        public init(_ value: ComAtprotoAdminDefs.RepoRef) {
            self = .comAtprotoAdminDefsRepoRef(value)
        }

        public init(_ value: ComAtprotoRepoStrongRef) {
            self = .comAtprotoRepoStrongRef(value)
        }

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
            guard let other = other as? ToolsOzoneModerationEmitEventSubjectUnion else { return false }
            return self == other
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .comAtprotoAdminDefsRepoRef(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "com.atproto.admin.defs#repoRef")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .comAtprotoRepoStrongRef(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "com.atproto.repo.strongRef")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

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
                }
                return map
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .comAtprotoAdminDefsRepoRef(value):
                return value.hasPendingData
            case let .comAtprotoRepoStrongRef(value):
                return value.hasPendingData
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .comAtprotoAdminDefsRepoRef(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .comAtprotoAdminDefsRepoRef(value)
            case var .comAtprotoRepoStrongRef(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .comAtprotoRepoStrongRef(value)
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
