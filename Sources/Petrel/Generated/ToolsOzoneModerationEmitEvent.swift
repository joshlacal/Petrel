import Foundation



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
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.event = try container.decode(InputEventUnion.self, forKey: .event)
                
                
                self.subject = try container.decode(InputSubjectUnion.self, forKey: .subject)
                
                
                self.subjectBlobCids = try container.decodeIfPresent([String].self, forKey: .subjectBlobCids)
                
                
                self.createdBy = try container.decode(String.self, forKey: .createdBy)
                
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
        }
    public typealias Output = ToolsOzoneModerationDefs.ModEventView
            
public enum Error: String, Swift.Error, CustomStringConvertible {
                case subjectHasAction = "SubjectHasAction."
            public var description: String {
                return self.rawValue
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
        case .toolsOzoneModerationDefsModEventDivert(let value):
            try container.encode("tools.ozone.moderation.defs#modEventDivert", forKey: .type)
            try value.encode(to: encoder)
        case .toolsOzoneModerationDefsModEventTag(let value):
            try container.encode("tools.ozone.moderation.defs#modEventTag", forKey: .type)
            try value.encode(to: encoder)
        case .toolsOzoneModerationDefsAccountEvent(let value):
            try container.encode("tools.ozone.moderation.defs#accountEvent", forKey: .type)
            try value.encode(to: encoder)
        case .toolsOzoneModerationDefsIdentityEvent(let value):
            try container.encode("tools.ozone.moderation.defs#identityEvent", forKey: .type)
            try value.encode(to: encoder)
        case .toolsOzoneModerationDefsRecordEvent(let value):
            try container.encode("tools.ozone.moderation.defs#recordEvent", forKey: .type)
            try value.encode(to: encoder)
        case .toolsOzoneModerationDefsModEventPriorityScore(let value):
            try container.encode("tools.ozone.moderation.defs#modEventPriorityScore", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let container):
            try container.encode(to: encoder)
        
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
        case .toolsOzoneModerationDefsModEventDivert(let value):
            hasher.combine("tools.ozone.moderation.defs#modEventDivert")
            hasher.combine(value)
        case .toolsOzoneModerationDefsModEventTag(let value):
            hasher.combine("tools.ozone.moderation.defs#modEventTag")
            hasher.combine(value)
        case .toolsOzoneModerationDefsAccountEvent(let value):
            hasher.combine("tools.ozone.moderation.defs#accountEvent")
            hasher.combine(value)
        case .toolsOzoneModerationDefsIdentityEvent(let value):
            hasher.combine("tools.ozone.moderation.defs#identityEvent")
            hasher.combine(value)
        case .toolsOzoneModerationDefsRecordEvent(let value):
            hasher.combine("tools.ozone.moderation.defs#recordEvent")
            hasher.combine(value)
        case .toolsOzoneModerationDefsModEventPriorityScore(let value):
            hasher.combine("tools.ozone.moderation.defs#modEventPriorityScore")
            hasher.combine(value)
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: InputEventUnion, rhs: InputEventUnion) -> Bool {
        switch (lhs, rhs) {
        case (.toolsOzoneModerationDefsModEventTakedown(let lhsValue),
              .toolsOzoneModerationDefsModEventTakedown(let rhsValue)):
            return lhsValue == rhsValue
        case (.toolsOzoneModerationDefsModEventAcknowledge(let lhsValue),
              .toolsOzoneModerationDefsModEventAcknowledge(let rhsValue)):
            return lhsValue == rhsValue
        case (.toolsOzoneModerationDefsModEventEscalate(let lhsValue),
              .toolsOzoneModerationDefsModEventEscalate(let rhsValue)):
            return lhsValue == rhsValue
        case (.toolsOzoneModerationDefsModEventComment(let lhsValue),
              .toolsOzoneModerationDefsModEventComment(let rhsValue)):
            return lhsValue == rhsValue
        case (.toolsOzoneModerationDefsModEventLabel(let lhsValue),
              .toolsOzoneModerationDefsModEventLabel(let rhsValue)):
            return lhsValue == rhsValue
        case (.toolsOzoneModerationDefsModEventReport(let lhsValue),
              .toolsOzoneModerationDefsModEventReport(let rhsValue)):
            return lhsValue == rhsValue
        case (.toolsOzoneModerationDefsModEventMute(let lhsValue),
              .toolsOzoneModerationDefsModEventMute(let rhsValue)):
            return lhsValue == rhsValue
        case (.toolsOzoneModerationDefsModEventUnmute(let lhsValue),
              .toolsOzoneModerationDefsModEventUnmute(let rhsValue)):
            return lhsValue == rhsValue
        case (.toolsOzoneModerationDefsModEventMuteReporter(let lhsValue),
              .toolsOzoneModerationDefsModEventMuteReporter(let rhsValue)):
            return lhsValue == rhsValue
        case (.toolsOzoneModerationDefsModEventUnmuteReporter(let lhsValue),
              .toolsOzoneModerationDefsModEventUnmuteReporter(let rhsValue)):
            return lhsValue == rhsValue
        case (.toolsOzoneModerationDefsModEventReverseTakedown(let lhsValue),
              .toolsOzoneModerationDefsModEventReverseTakedown(let rhsValue)):
            return lhsValue == rhsValue
        case (.toolsOzoneModerationDefsModEventResolveAppeal(let lhsValue),
              .toolsOzoneModerationDefsModEventResolveAppeal(let rhsValue)):
            return lhsValue == rhsValue
        case (.toolsOzoneModerationDefsModEventEmail(let lhsValue),
              .toolsOzoneModerationDefsModEventEmail(let rhsValue)):
            return lhsValue == rhsValue
        case (.toolsOzoneModerationDefsModEventDivert(let lhsValue),
              .toolsOzoneModerationDefsModEventDivert(let rhsValue)):
            return lhsValue == rhsValue
        case (.toolsOzoneModerationDefsModEventTag(let lhsValue),
              .toolsOzoneModerationDefsModEventTag(let rhsValue)):
            return lhsValue == rhsValue
        case (.toolsOzoneModerationDefsAccountEvent(let lhsValue),
              .toolsOzoneModerationDefsAccountEvent(let rhsValue)):
            return lhsValue == rhsValue
        case (.toolsOzoneModerationDefsIdentityEvent(let lhsValue),
              .toolsOzoneModerationDefsIdentityEvent(let rhsValue)):
            return lhsValue == rhsValue
        case (.toolsOzoneModerationDefsRecordEvent(let lhsValue),
              .toolsOzoneModerationDefsRecordEvent(let rhsValue)):
            return lhsValue == rhsValue
        case (.toolsOzoneModerationDefsModEventPriorityScore(let lhsValue),
              .toolsOzoneModerationDefsModEventPriorityScore(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? InputEventUnion else { return false }
        return self == other
    }
    
    /// Property that indicates if this enum contains pending data that needs loading
    public var hasPendingData: Bool {
        switch self {
        
        case .toolsOzoneModerationDefsModEventTakedown(let value):
            return value.hasPendingData
        case .toolsOzoneModerationDefsModEventAcknowledge(let value):
            return value.hasPendingData
        case .toolsOzoneModerationDefsModEventEscalate(let value):
            return value.hasPendingData
        case .toolsOzoneModerationDefsModEventComment(let value):
            return value.hasPendingData
        case .toolsOzoneModerationDefsModEventLabel(let value):
            return value.hasPendingData
        case .toolsOzoneModerationDefsModEventReport(let value):
            return value.hasPendingData
        case .toolsOzoneModerationDefsModEventMute(let value):
            return value.hasPendingData
        case .toolsOzoneModerationDefsModEventUnmute(let value):
            return value.hasPendingData
        case .toolsOzoneModerationDefsModEventMuteReporter(let value):
            return value.hasPendingData
        case .toolsOzoneModerationDefsModEventUnmuteReporter(let value):
            return value.hasPendingData
        case .toolsOzoneModerationDefsModEventReverseTakedown(let value):
            return value.hasPendingData
        case .toolsOzoneModerationDefsModEventResolveAppeal(let value):
            return value.hasPendingData
        case .toolsOzoneModerationDefsModEventEmail(let value):
            return value.hasPendingData
        case .toolsOzoneModerationDefsModEventDivert(let value):
            return value.hasPendingData
        case .toolsOzoneModerationDefsModEventTag(let value):
            return value.hasPendingData
        case .toolsOzoneModerationDefsAccountEvent(let value):
            return value.hasPendingData
        case .toolsOzoneModerationDefsIdentityEvent(let value):
            return value.hasPendingData
        case .toolsOzoneModerationDefsRecordEvent(let value):
            return value.hasPendingData
        case .toolsOzoneModerationDefsModEventPriorityScore(let value):
            return value.hasPendingData
        case .unexpected:
            return false
        }
    }
    
    /// Attempts to load any pending data in this enum or its children
    public mutating func loadPendingData() async {
        switch self {
        
        case .toolsOzoneModerationDefsModEventTakedown(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .toolsOzoneModerationDefsModEventTakedown(value)
        case .toolsOzoneModerationDefsModEventAcknowledge(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .toolsOzoneModerationDefsModEventAcknowledge(value)
        case .toolsOzoneModerationDefsModEventEscalate(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .toolsOzoneModerationDefsModEventEscalate(value)
        case .toolsOzoneModerationDefsModEventComment(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .toolsOzoneModerationDefsModEventComment(value)
        case .toolsOzoneModerationDefsModEventLabel(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .toolsOzoneModerationDefsModEventLabel(value)
        case .toolsOzoneModerationDefsModEventReport(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .toolsOzoneModerationDefsModEventReport(value)
        case .toolsOzoneModerationDefsModEventMute(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .toolsOzoneModerationDefsModEventMute(value)
        case .toolsOzoneModerationDefsModEventUnmute(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .toolsOzoneModerationDefsModEventUnmute(value)
        case .toolsOzoneModerationDefsModEventMuteReporter(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .toolsOzoneModerationDefsModEventMuteReporter(value)
        case .toolsOzoneModerationDefsModEventUnmuteReporter(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .toolsOzoneModerationDefsModEventUnmuteReporter(value)
        case .toolsOzoneModerationDefsModEventReverseTakedown(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .toolsOzoneModerationDefsModEventReverseTakedown(value)
        case .toolsOzoneModerationDefsModEventResolveAppeal(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .toolsOzoneModerationDefsModEventResolveAppeal(value)
        case .toolsOzoneModerationDefsModEventEmail(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .toolsOzoneModerationDefsModEventEmail(value)
        case .toolsOzoneModerationDefsModEventDivert(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .toolsOzoneModerationDefsModEventDivert(value)
        case .toolsOzoneModerationDefsModEventTag(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .toolsOzoneModerationDefsModEventTag(value)
        case .toolsOzoneModerationDefsAccountEvent(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .toolsOzoneModerationDefsAccountEvent(value)
        case .toolsOzoneModerationDefsIdentityEvent(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .toolsOzoneModerationDefsIdentityEvent(value)
        case .toolsOzoneModerationDefsRecordEvent(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .toolsOzoneModerationDefsRecordEvent(value)
        case .toolsOzoneModerationDefsModEventPriorityScore(var value):
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
        case .comAtprotoAdminDefsRepoRef(let value):
            try container.encode("com.atproto.admin.defs#repoRef", forKey: .type)
            try value.encode(to: encoder)
        case .comAtprotoRepoStrongRef(let value):
            try container.encode("com.atproto.repo.strongRef", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let container):
            try container.encode(to: encoder)
        
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
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: InputSubjectUnion, rhs: InputSubjectUnion) -> Bool {
        switch (lhs, rhs) {
        case (.comAtprotoAdminDefsRepoRef(let lhsValue),
              .comAtprotoAdminDefsRepoRef(let rhsValue)):
            return lhsValue == rhsValue
        case (.comAtprotoRepoStrongRef(let lhsValue),
              .comAtprotoRepoStrongRef(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? InputSubjectUnion else { return false }
        return self == other
    }
    
    /// Property that indicates if this enum contains pending data that needs loading
    public var hasPendingData: Bool {
        switch self {
        
        case .comAtprotoAdminDefsRepoRef(let value):
            return value.hasPendingData
        case .comAtprotoRepoStrongRef(let value):
            return value.hasPendingData
        case .unexpected:
            return false
        }
    }
    
    /// Attempts to load any pending data in this enum or its children
    public mutating func loadPendingData() async {
        switch self {
        
        case .comAtprotoAdminDefsRepoRef(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .comAtprotoAdminDefsRepoRef(value)
        case .comAtprotoRepoStrongRef(var value):
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
        case .toolsOzoneModerationDefsModEventDivert(let value):
            try container.encode("tools.ozone.moderation.defs#modEventDivert", forKey: .type)
            try value.encode(to: encoder)
        case .toolsOzoneModerationDefsModEventTag(let value):
            try container.encode("tools.ozone.moderation.defs#modEventTag", forKey: .type)
            try value.encode(to: encoder)
        case .toolsOzoneModerationDefsAccountEvent(let value):
            try container.encode("tools.ozone.moderation.defs#accountEvent", forKey: .type)
            try value.encode(to: encoder)
        case .toolsOzoneModerationDefsIdentityEvent(let value):
            try container.encode("tools.ozone.moderation.defs#identityEvent", forKey: .type)
            try value.encode(to: encoder)
        case .toolsOzoneModerationDefsRecordEvent(let value):
            try container.encode("tools.ozone.moderation.defs#recordEvent", forKey: .type)
            try value.encode(to: encoder)
        case .toolsOzoneModerationDefsModEventPriorityScore(let value):
            try container.encode("tools.ozone.moderation.defs#modEventPriorityScore", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let container):
            try container.encode(to: encoder)
        
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
        case .toolsOzoneModerationDefsModEventDivert(let value):
            hasher.combine("tools.ozone.moderation.defs#modEventDivert")
            hasher.combine(value)
        case .toolsOzoneModerationDefsModEventTag(let value):
            hasher.combine("tools.ozone.moderation.defs#modEventTag")
            hasher.combine(value)
        case .toolsOzoneModerationDefsAccountEvent(let value):
            hasher.combine("tools.ozone.moderation.defs#accountEvent")
            hasher.combine(value)
        case .toolsOzoneModerationDefsIdentityEvent(let value):
            hasher.combine("tools.ozone.moderation.defs#identityEvent")
            hasher.combine(value)
        case .toolsOzoneModerationDefsRecordEvent(let value):
            hasher.combine("tools.ozone.moderation.defs#recordEvent")
            hasher.combine(value)
        case .toolsOzoneModerationDefsModEventPriorityScore(let value):
            hasher.combine("tools.ozone.moderation.defs#modEventPriorityScore")
            hasher.combine(value)
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: ToolsOzoneModerationEmitEventEventUnion, rhs: ToolsOzoneModerationEmitEventEventUnion) -> Bool {
        switch (lhs, rhs) {
        case (.toolsOzoneModerationDefsModEventTakedown(let lhsValue),
              .toolsOzoneModerationDefsModEventTakedown(let rhsValue)):
            return lhsValue == rhsValue
        case (.toolsOzoneModerationDefsModEventAcknowledge(let lhsValue),
              .toolsOzoneModerationDefsModEventAcknowledge(let rhsValue)):
            return lhsValue == rhsValue
        case (.toolsOzoneModerationDefsModEventEscalate(let lhsValue),
              .toolsOzoneModerationDefsModEventEscalate(let rhsValue)):
            return lhsValue == rhsValue
        case (.toolsOzoneModerationDefsModEventComment(let lhsValue),
              .toolsOzoneModerationDefsModEventComment(let rhsValue)):
            return lhsValue == rhsValue
        case (.toolsOzoneModerationDefsModEventLabel(let lhsValue),
              .toolsOzoneModerationDefsModEventLabel(let rhsValue)):
            return lhsValue == rhsValue
        case (.toolsOzoneModerationDefsModEventReport(let lhsValue),
              .toolsOzoneModerationDefsModEventReport(let rhsValue)):
            return lhsValue == rhsValue
        case (.toolsOzoneModerationDefsModEventMute(let lhsValue),
              .toolsOzoneModerationDefsModEventMute(let rhsValue)):
            return lhsValue == rhsValue
        case (.toolsOzoneModerationDefsModEventUnmute(let lhsValue),
              .toolsOzoneModerationDefsModEventUnmute(let rhsValue)):
            return lhsValue == rhsValue
        case (.toolsOzoneModerationDefsModEventMuteReporter(let lhsValue),
              .toolsOzoneModerationDefsModEventMuteReporter(let rhsValue)):
            return lhsValue == rhsValue
        case (.toolsOzoneModerationDefsModEventUnmuteReporter(let lhsValue),
              .toolsOzoneModerationDefsModEventUnmuteReporter(let rhsValue)):
            return lhsValue == rhsValue
        case (.toolsOzoneModerationDefsModEventReverseTakedown(let lhsValue),
              .toolsOzoneModerationDefsModEventReverseTakedown(let rhsValue)):
            return lhsValue == rhsValue
        case (.toolsOzoneModerationDefsModEventResolveAppeal(let lhsValue),
              .toolsOzoneModerationDefsModEventResolveAppeal(let rhsValue)):
            return lhsValue == rhsValue
        case (.toolsOzoneModerationDefsModEventEmail(let lhsValue),
              .toolsOzoneModerationDefsModEventEmail(let rhsValue)):
            return lhsValue == rhsValue
        case (.toolsOzoneModerationDefsModEventDivert(let lhsValue),
              .toolsOzoneModerationDefsModEventDivert(let rhsValue)):
            return lhsValue == rhsValue
        case (.toolsOzoneModerationDefsModEventTag(let lhsValue),
              .toolsOzoneModerationDefsModEventTag(let rhsValue)):
            return lhsValue == rhsValue
        case (.toolsOzoneModerationDefsAccountEvent(let lhsValue),
              .toolsOzoneModerationDefsAccountEvent(let rhsValue)):
            return lhsValue == rhsValue
        case (.toolsOzoneModerationDefsIdentityEvent(let lhsValue),
              .toolsOzoneModerationDefsIdentityEvent(let rhsValue)):
            return lhsValue == rhsValue
        case (.toolsOzoneModerationDefsRecordEvent(let lhsValue),
              .toolsOzoneModerationDefsRecordEvent(let rhsValue)):
            return lhsValue == rhsValue
        case (.toolsOzoneModerationDefsModEventPriorityScore(let lhsValue),
              .toolsOzoneModerationDefsModEventPriorityScore(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? ToolsOzoneModerationEmitEventEventUnion else { return false }
        return self == other
    }
    
    /// Property that indicates if this enum contains pending data that needs loading
    public var hasPendingData: Bool {
        switch self {
        
        case .toolsOzoneModerationDefsModEventTakedown(let value):
            return value.hasPendingData
        case .toolsOzoneModerationDefsModEventAcknowledge(let value):
            return value.hasPendingData
        case .toolsOzoneModerationDefsModEventEscalate(let value):
            return value.hasPendingData
        case .toolsOzoneModerationDefsModEventComment(let value):
            return value.hasPendingData
        case .toolsOzoneModerationDefsModEventLabel(let value):
            return value.hasPendingData
        case .toolsOzoneModerationDefsModEventReport(let value):
            return value.hasPendingData
        case .toolsOzoneModerationDefsModEventMute(let value):
            return value.hasPendingData
        case .toolsOzoneModerationDefsModEventUnmute(let value):
            return value.hasPendingData
        case .toolsOzoneModerationDefsModEventMuteReporter(let value):
            return value.hasPendingData
        case .toolsOzoneModerationDefsModEventUnmuteReporter(let value):
            return value.hasPendingData
        case .toolsOzoneModerationDefsModEventReverseTakedown(let value):
            return value.hasPendingData
        case .toolsOzoneModerationDefsModEventResolveAppeal(let value):
            return value.hasPendingData
        case .toolsOzoneModerationDefsModEventEmail(let value):
            return value.hasPendingData
        case .toolsOzoneModerationDefsModEventDivert(let value):
            return value.hasPendingData
        case .toolsOzoneModerationDefsModEventTag(let value):
            return value.hasPendingData
        case .toolsOzoneModerationDefsAccountEvent(let value):
            return value.hasPendingData
        case .toolsOzoneModerationDefsIdentityEvent(let value):
            return value.hasPendingData
        case .toolsOzoneModerationDefsRecordEvent(let value):
            return value.hasPendingData
        case .toolsOzoneModerationDefsModEventPriorityScore(let value):
            return value.hasPendingData
        case .unexpected:
            return false
        }
    }
    
    /// Attempts to load any pending data in this enum or its children
    public mutating func loadPendingData() async {
        switch self {
        
        case .toolsOzoneModerationDefsModEventTakedown(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .toolsOzoneModerationDefsModEventTakedown(value)
        case .toolsOzoneModerationDefsModEventAcknowledge(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .toolsOzoneModerationDefsModEventAcknowledge(value)
        case .toolsOzoneModerationDefsModEventEscalate(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .toolsOzoneModerationDefsModEventEscalate(value)
        case .toolsOzoneModerationDefsModEventComment(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .toolsOzoneModerationDefsModEventComment(value)
        case .toolsOzoneModerationDefsModEventLabel(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .toolsOzoneModerationDefsModEventLabel(value)
        case .toolsOzoneModerationDefsModEventReport(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .toolsOzoneModerationDefsModEventReport(value)
        case .toolsOzoneModerationDefsModEventMute(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .toolsOzoneModerationDefsModEventMute(value)
        case .toolsOzoneModerationDefsModEventUnmute(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .toolsOzoneModerationDefsModEventUnmute(value)
        case .toolsOzoneModerationDefsModEventMuteReporter(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .toolsOzoneModerationDefsModEventMuteReporter(value)
        case .toolsOzoneModerationDefsModEventUnmuteReporter(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .toolsOzoneModerationDefsModEventUnmuteReporter(value)
        case .toolsOzoneModerationDefsModEventReverseTakedown(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .toolsOzoneModerationDefsModEventReverseTakedown(value)
        case .toolsOzoneModerationDefsModEventResolveAppeal(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .toolsOzoneModerationDefsModEventResolveAppeal(value)
        case .toolsOzoneModerationDefsModEventEmail(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .toolsOzoneModerationDefsModEventEmail(value)
        case .toolsOzoneModerationDefsModEventDivert(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .toolsOzoneModerationDefsModEventDivert(value)
        case .toolsOzoneModerationDefsModEventTag(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .toolsOzoneModerationDefsModEventTag(value)
        case .toolsOzoneModerationDefsAccountEvent(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .toolsOzoneModerationDefsAccountEvent(value)
        case .toolsOzoneModerationDefsIdentityEvent(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .toolsOzoneModerationDefsIdentityEvent(value)
        case .toolsOzoneModerationDefsRecordEvent(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .toolsOzoneModerationDefsRecordEvent(value)
        case .toolsOzoneModerationDefsModEventPriorityScore(var value):
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
        case .comAtprotoAdminDefsRepoRef(let value):
            try container.encode("com.atproto.admin.defs#repoRef", forKey: .type)
            try value.encode(to: encoder)
        case .comAtprotoRepoStrongRef(let value):
            try container.encode("com.atproto.repo.strongRef", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let container):
            try container.encode(to: encoder)
        
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
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: ToolsOzoneModerationEmitEventSubjectUnion, rhs: ToolsOzoneModerationEmitEventSubjectUnion) -> Bool {
        switch (lhs, rhs) {
        case (.comAtprotoAdminDefsRepoRef(let lhsValue),
              .comAtprotoAdminDefsRepoRef(let rhsValue)):
            return lhsValue == rhsValue
        case (.comAtprotoRepoStrongRef(let lhsValue),
              .comAtprotoRepoStrongRef(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? ToolsOzoneModerationEmitEventSubjectUnion else { return false }
        return self == other
    }
    
    /// Property that indicates if this enum contains pending data that needs loading
    public var hasPendingData: Bool {
        switch self {
        
        case .comAtprotoAdminDefsRepoRef(let value):
            return value.hasPendingData
        case .comAtprotoRepoStrongRef(let value):
            return value.hasPendingData
        case .unexpected:
            return false
        }
    }
    
    /// Attempts to load any pending data in this enum or its children
    public mutating func loadPendingData() async {
        switch self {
        
        case .comAtprotoAdminDefsRepoRef(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .comAtprotoAdminDefsRepoRef(value)
        case .comAtprotoRepoStrongRef(var value):
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
        
        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(ToolsOzoneModerationEmitEvent.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
        
    }
    
}
                           
