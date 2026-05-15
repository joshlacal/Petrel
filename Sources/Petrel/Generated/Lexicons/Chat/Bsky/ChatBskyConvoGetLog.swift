import Foundation



// lexicon: 1, id: chat.bsky.convo.getLog


public struct ChatBskyConvoGetLog { 

    public static let typeIdentifier = "chat.bsky.convo.getLog"    
public struct Parameters: Parametrizable {
        public let cursor: String?
        
        public init(
            cursor: String? = nil
            ) {
            self.cursor = cursor
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let cursor: String?
        
        public let logs: [OutputLogsUnion]
        
        
        
        // Standard public initializer
        public init(
            
            
            cursor: String? = nil,
            
            logs: [OutputLogsUnion]
            
            
        ) {
            
            
            self.cursor = cursor
            
            self.logs = logs
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
            
            
            self.logs = try container.decode([OutputLogsUnion].self, forKey: .logs)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)
            
            
            try container.encode(logs, forKey: .logs)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR
                let cursorValue = try value.toCBORValue()
                map = map.adding(key: "cursor", value: cursorValue)
            }
            
            
            
            let logsValue = try logs.toCBORValue()
            map = map.adding(key: "logs", value: logsValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case cursor
            case logs
        }
        
    }






public enum OutputLogsUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
    case chatBskyConvoDefsLogBeginConvo(ChatBskyConvoDefs.LogBeginConvo)
    case chatBskyConvoDefsLogAcceptConvo(ChatBskyConvoDefs.LogAcceptConvo)
    case chatBskyConvoDefsLogLeaveConvo(ChatBskyConvoDefs.LogLeaveConvo)
    case chatBskyConvoDefsLogMuteConvo(ChatBskyConvoDefs.LogMuteConvo)
    case chatBskyConvoDefsLogUnmuteConvo(ChatBskyConvoDefs.LogUnmuteConvo)
    case chatBskyConvoDefsLogCreateMessage(ChatBskyConvoDefs.LogCreateMessage)
    case chatBskyConvoDefsLogDeleteMessage(ChatBskyConvoDefs.LogDeleteMessage)
    case chatBskyConvoDefsLogReadMessage(ChatBskyConvoDefs.LogReadMessage)
    case chatBskyConvoDefsLogAddReaction(ChatBskyConvoDefs.LogAddReaction)
    case chatBskyConvoDefsLogRemoveReaction(ChatBskyConvoDefs.LogRemoveReaction)
    case chatBskyConvoDefsLogReadConvo(ChatBskyConvoDefs.LogReadConvo)
    case chatBskyConvoDefsLogAddMember(ChatBskyConvoDefs.LogAddMember)
    case chatBskyConvoDefsLogRemoveMember(ChatBskyConvoDefs.LogRemoveMember)
    case chatBskyConvoDefsLogMemberJoin(ChatBskyConvoDefs.LogMemberJoin)
    case chatBskyConvoDefsLogMemberLeave(ChatBskyConvoDefs.LogMemberLeave)
    case chatBskyConvoDefsLogLockConvo(ChatBskyConvoDefs.LogLockConvo)
    case chatBskyConvoDefsLogUnlockConvo(ChatBskyConvoDefs.LogUnlockConvo)
    case chatBskyConvoDefsLogLockConvoPermanently(ChatBskyConvoDefs.LogLockConvoPermanently)
    case chatBskyConvoDefsLogEditGroup(ChatBskyConvoDefs.LogEditGroup)
    case chatBskyConvoDefsLogCreateJoinLink(ChatBskyConvoDefs.LogCreateJoinLink)
    case chatBskyConvoDefsLogEditJoinLink(ChatBskyConvoDefs.LogEditJoinLink)
    case chatBskyConvoDefsLogEnableJoinLink(ChatBskyConvoDefs.LogEnableJoinLink)
    case chatBskyConvoDefsLogDisableJoinLink(ChatBskyConvoDefs.LogDisableJoinLink)
    case chatBskyConvoDefsLogIncomingJoinRequest(ChatBskyConvoDefs.LogIncomingJoinRequest)
    case chatBskyConvoDefsLogApproveJoinRequest(ChatBskyConvoDefs.LogApproveJoinRequest)
    case chatBskyConvoDefsLogRejectJoinRequest(ChatBskyConvoDefs.LogRejectJoinRequest)
    case chatBskyConvoDefsLogOutgoingJoinRequest(ChatBskyConvoDefs.LogOutgoingJoinRequest)
    case unexpected(ATProtocolValueContainer)
    public init(_ value: ChatBskyConvoDefs.LogBeginConvo) {
        self = .chatBskyConvoDefsLogBeginConvo(value)
    }
    public init(_ value: ChatBskyConvoDefs.LogAcceptConvo) {
        self = .chatBskyConvoDefsLogAcceptConvo(value)
    }
    public init(_ value: ChatBskyConvoDefs.LogLeaveConvo) {
        self = .chatBskyConvoDefsLogLeaveConvo(value)
    }
    public init(_ value: ChatBskyConvoDefs.LogMuteConvo) {
        self = .chatBskyConvoDefsLogMuteConvo(value)
    }
    public init(_ value: ChatBskyConvoDefs.LogUnmuteConvo) {
        self = .chatBskyConvoDefsLogUnmuteConvo(value)
    }
    public init(_ value: ChatBskyConvoDefs.LogCreateMessage) {
        self = .chatBskyConvoDefsLogCreateMessage(value)
    }
    public init(_ value: ChatBskyConvoDefs.LogDeleteMessage) {
        self = .chatBskyConvoDefsLogDeleteMessage(value)
    }
    public init(_ value: ChatBskyConvoDefs.LogReadMessage) {
        self = .chatBskyConvoDefsLogReadMessage(value)
    }
    public init(_ value: ChatBskyConvoDefs.LogAddReaction) {
        self = .chatBskyConvoDefsLogAddReaction(value)
    }
    public init(_ value: ChatBskyConvoDefs.LogRemoveReaction) {
        self = .chatBskyConvoDefsLogRemoveReaction(value)
    }
    public init(_ value: ChatBskyConvoDefs.LogReadConvo) {
        self = .chatBskyConvoDefsLogReadConvo(value)
    }
    public init(_ value: ChatBskyConvoDefs.LogAddMember) {
        self = .chatBskyConvoDefsLogAddMember(value)
    }
    public init(_ value: ChatBskyConvoDefs.LogRemoveMember) {
        self = .chatBskyConvoDefsLogRemoveMember(value)
    }
    public init(_ value: ChatBskyConvoDefs.LogMemberJoin) {
        self = .chatBskyConvoDefsLogMemberJoin(value)
    }
    public init(_ value: ChatBskyConvoDefs.LogMemberLeave) {
        self = .chatBskyConvoDefsLogMemberLeave(value)
    }
    public init(_ value: ChatBskyConvoDefs.LogLockConvo) {
        self = .chatBskyConvoDefsLogLockConvo(value)
    }
    public init(_ value: ChatBskyConvoDefs.LogUnlockConvo) {
        self = .chatBskyConvoDefsLogUnlockConvo(value)
    }
    public init(_ value: ChatBskyConvoDefs.LogLockConvoPermanently) {
        self = .chatBskyConvoDefsLogLockConvoPermanently(value)
    }
    public init(_ value: ChatBskyConvoDefs.LogEditGroup) {
        self = .chatBskyConvoDefsLogEditGroup(value)
    }
    public init(_ value: ChatBskyConvoDefs.LogCreateJoinLink) {
        self = .chatBskyConvoDefsLogCreateJoinLink(value)
    }
    public init(_ value: ChatBskyConvoDefs.LogEditJoinLink) {
        self = .chatBskyConvoDefsLogEditJoinLink(value)
    }
    public init(_ value: ChatBskyConvoDefs.LogEnableJoinLink) {
        self = .chatBskyConvoDefsLogEnableJoinLink(value)
    }
    public init(_ value: ChatBskyConvoDefs.LogDisableJoinLink) {
        self = .chatBskyConvoDefsLogDisableJoinLink(value)
    }
    public init(_ value: ChatBskyConvoDefs.LogIncomingJoinRequest) {
        self = .chatBskyConvoDefsLogIncomingJoinRequest(value)
    }
    public init(_ value: ChatBskyConvoDefs.LogApproveJoinRequest) {
        self = .chatBskyConvoDefsLogApproveJoinRequest(value)
    }
    public init(_ value: ChatBskyConvoDefs.LogRejectJoinRequest) {
        self = .chatBskyConvoDefsLogRejectJoinRequest(value)
    }
    public init(_ value: ChatBskyConvoDefs.LogOutgoingJoinRequest) {
        self = .chatBskyConvoDefsLogOutgoingJoinRequest(value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)

        switch typeValue {
        case "chat.bsky.convo.defs#logBeginConvo":
            let value = try ChatBskyConvoDefs.LogBeginConvo(from: decoder)
            self = .chatBskyConvoDefsLogBeginConvo(value)
        case "chat.bsky.convo.defs#logAcceptConvo":
            let value = try ChatBskyConvoDefs.LogAcceptConvo(from: decoder)
            self = .chatBskyConvoDefsLogAcceptConvo(value)
        case "chat.bsky.convo.defs#logLeaveConvo":
            let value = try ChatBskyConvoDefs.LogLeaveConvo(from: decoder)
            self = .chatBskyConvoDefsLogLeaveConvo(value)
        case "chat.bsky.convo.defs#logMuteConvo":
            let value = try ChatBskyConvoDefs.LogMuteConvo(from: decoder)
            self = .chatBskyConvoDefsLogMuteConvo(value)
        case "chat.bsky.convo.defs#logUnmuteConvo":
            let value = try ChatBskyConvoDefs.LogUnmuteConvo(from: decoder)
            self = .chatBskyConvoDefsLogUnmuteConvo(value)
        case "chat.bsky.convo.defs#logCreateMessage":
            let value = try ChatBskyConvoDefs.LogCreateMessage(from: decoder)
            self = .chatBskyConvoDefsLogCreateMessage(value)
        case "chat.bsky.convo.defs#logDeleteMessage":
            let value = try ChatBskyConvoDefs.LogDeleteMessage(from: decoder)
            self = .chatBskyConvoDefsLogDeleteMessage(value)
        case "chat.bsky.convo.defs#logReadMessage":
            let value = try ChatBskyConvoDefs.LogReadMessage(from: decoder)
            self = .chatBskyConvoDefsLogReadMessage(value)
        case "chat.bsky.convo.defs#logAddReaction":
            let value = try ChatBskyConvoDefs.LogAddReaction(from: decoder)
            self = .chatBskyConvoDefsLogAddReaction(value)
        case "chat.bsky.convo.defs#logRemoveReaction":
            let value = try ChatBskyConvoDefs.LogRemoveReaction(from: decoder)
            self = .chatBskyConvoDefsLogRemoveReaction(value)
        case "chat.bsky.convo.defs#logReadConvo":
            let value = try ChatBskyConvoDefs.LogReadConvo(from: decoder)
            self = .chatBskyConvoDefsLogReadConvo(value)
        case "chat.bsky.convo.defs#logAddMember":
            let value = try ChatBskyConvoDefs.LogAddMember(from: decoder)
            self = .chatBskyConvoDefsLogAddMember(value)
        case "chat.bsky.convo.defs#logRemoveMember":
            let value = try ChatBskyConvoDefs.LogRemoveMember(from: decoder)
            self = .chatBskyConvoDefsLogRemoveMember(value)
        case "chat.bsky.convo.defs#logMemberJoin":
            let value = try ChatBskyConvoDefs.LogMemberJoin(from: decoder)
            self = .chatBskyConvoDefsLogMemberJoin(value)
        case "chat.bsky.convo.defs#logMemberLeave":
            let value = try ChatBskyConvoDefs.LogMemberLeave(from: decoder)
            self = .chatBskyConvoDefsLogMemberLeave(value)
        case "chat.bsky.convo.defs#logLockConvo":
            let value = try ChatBskyConvoDefs.LogLockConvo(from: decoder)
            self = .chatBskyConvoDefsLogLockConvo(value)
        case "chat.bsky.convo.defs#logUnlockConvo":
            let value = try ChatBskyConvoDefs.LogUnlockConvo(from: decoder)
            self = .chatBskyConvoDefsLogUnlockConvo(value)
        case "chat.bsky.convo.defs#logLockConvoPermanently":
            let value = try ChatBskyConvoDefs.LogLockConvoPermanently(from: decoder)
            self = .chatBskyConvoDefsLogLockConvoPermanently(value)
        case "chat.bsky.convo.defs#logEditGroup":
            let value = try ChatBskyConvoDefs.LogEditGroup(from: decoder)
            self = .chatBskyConvoDefsLogEditGroup(value)
        case "chat.bsky.convo.defs#logCreateJoinLink":
            let value = try ChatBskyConvoDefs.LogCreateJoinLink(from: decoder)
            self = .chatBskyConvoDefsLogCreateJoinLink(value)
        case "chat.bsky.convo.defs#logEditJoinLink":
            let value = try ChatBskyConvoDefs.LogEditJoinLink(from: decoder)
            self = .chatBskyConvoDefsLogEditJoinLink(value)
        case "chat.bsky.convo.defs#logEnableJoinLink":
            let value = try ChatBskyConvoDefs.LogEnableJoinLink(from: decoder)
            self = .chatBskyConvoDefsLogEnableJoinLink(value)
        case "chat.bsky.convo.defs#logDisableJoinLink":
            let value = try ChatBskyConvoDefs.LogDisableJoinLink(from: decoder)
            self = .chatBskyConvoDefsLogDisableJoinLink(value)
        case "chat.bsky.convo.defs#logIncomingJoinRequest":
            let value = try ChatBskyConvoDefs.LogIncomingJoinRequest(from: decoder)
            self = .chatBskyConvoDefsLogIncomingJoinRequest(value)
        case "chat.bsky.convo.defs#logApproveJoinRequest":
            let value = try ChatBskyConvoDefs.LogApproveJoinRequest(from: decoder)
            self = .chatBskyConvoDefsLogApproveJoinRequest(value)
        case "chat.bsky.convo.defs#logRejectJoinRequest":
            let value = try ChatBskyConvoDefs.LogRejectJoinRequest(from: decoder)
            self = .chatBskyConvoDefsLogRejectJoinRequest(value)
        case "chat.bsky.convo.defs#logOutgoingJoinRequest":
            let value = try ChatBskyConvoDefs.LogOutgoingJoinRequest(from: decoder)
            self = .chatBskyConvoDefsLogOutgoingJoinRequest(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .chatBskyConvoDefsLogBeginConvo(let value):
            try container.encode("chat.bsky.convo.defs#logBeginConvo", forKey: .type)
            try value.encode(to: encoder)
        case .chatBskyConvoDefsLogAcceptConvo(let value):
            try container.encode("chat.bsky.convo.defs#logAcceptConvo", forKey: .type)
            try value.encode(to: encoder)
        case .chatBskyConvoDefsLogLeaveConvo(let value):
            try container.encode("chat.bsky.convo.defs#logLeaveConvo", forKey: .type)
            try value.encode(to: encoder)
        case .chatBskyConvoDefsLogMuteConvo(let value):
            try container.encode("chat.bsky.convo.defs#logMuteConvo", forKey: .type)
            try value.encode(to: encoder)
        case .chatBskyConvoDefsLogUnmuteConvo(let value):
            try container.encode("chat.bsky.convo.defs#logUnmuteConvo", forKey: .type)
            try value.encode(to: encoder)
        case .chatBskyConvoDefsLogCreateMessage(let value):
            try container.encode("chat.bsky.convo.defs#logCreateMessage", forKey: .type)
            try value.encode(to: encoder)
        case .chatBskyConvoDefsLogDeleteMessage(let value):
            try container.encode("chat.bsky.convo.defs#logDeleteMessage", forKey: .type)
            try value.encode(to: encoder)
        case .chatBskyConvoDefsLogReadMessage(let value):
            try container.encode("chat.bsky.convo.defs#logReadMessage", forKey: .type)
            try value.encode(to: encoder)
        case .chatBskyConvoDefsLogAddReaction(let value):
            try container.encode("chat.bsky.convo.defs#logAddReaction", forKey: .type)
            try value.encode(to: encoder)
        case .chatBskyConvoDefsLogRemoveReaction(let value):
            try container.encode("chat.bsky.convo.defs#logRemoveReaction", forKey: .type)
            try value.encode(to: encoder)
        case .chatBskyConvoDefsLogReadConvo(let value):
            try container.encode("chat.bsky.convo.defs#logReadConvo", forKey: .type)
            try value.encode(to: encoder)
        case .chatBskyConvoDefsLogAddMember(let value):
            try container.encode("chat.bsky.convo.defs#logAddMember", forKey: .type)
            try value.encode(to: encoder)
        case .chatBskyConvoDefsLogRemoveMember(let value):
            try container.encode("chat.bsky.convo.defs#logRemoveMember", forKey: .type)
            try value.encode(to: encoder)
        case .chatBskyConvoDefsLogMemberJoin(let value):
            try container.encode("chat.bsky.convo.defs#logMemberJoin", forKey: .type)
            try value.encode(to: encoder)
        case .chatBskyConvoDefsLogMemberLeave(let value):
            try container.encode("chat.bsky.convo.defs#logMemberLeave", forKey: .type)
            try value.encode(to: encoder)
        case .chatBskyConvoDefsLogLockConvo(let value):
            try container.encode("chat.bsky.convo.defs#logLockConvo", forKey: .type)
            try value.encode(to: encoder)
        case .chatBskyConvoDefsLogUnlockConvo(let value):
            try container.encode("chat.bsky.convo.defs#logUnlockConvo", forKey: .type)
            try value.encode(to: encoder)
        case .chatBskyConvoDefsLogLockConvoPermanently(let value):
            try container.encode("chat.bsky.convo.defs#logLockConvoPermanently", forKey: .type)
            try value.encode(to: encoder)
        case .chatBskyConvoDefsLogEditGroup(let value):
            try container.encode("chat.bsky.convo.defs#logEditGroup", forKey: .type)
            try value.encode(to: encoder)
        case .chatBskyConvoDefsLogCreateJoinLink(let value):
            try container.encode("chat.bsky.convo.defs#logCreateJoinLink", forKey: .type)
            try value.encode(to: encoder)
        case .chatBskyConvoDefsLogEditJoinLink(let value):
            try container.encode("chat.bsky.convo.defs#logEditJoinLink", forKey: .type)
            try value.encode(to: encoder)
        case .chatBskyConvoDefsLogEnableJoinLink(let value):
            try container.encode("chat.bsky.convo.defs#logEnableJoinLink", forKey: .type)
            try value.encode(to: encoder)
        case .chatBskyConvoDefsLogDisableJoinLink(let value):
            try container.encode("chat.bsky.convo.defs#logDisableJoinLink", forKey: .type)
            try value.encode(to: encoder)
        case .chatBskyConvoDefsLogIncomingJoinRequest(let value):
            try container.encode("chat.bsky.convo.defs#logIncomingJoinRequest", forKey: .type)
            try value.encode(to: encoder)
        case .chatBskyConvoDefsLogApproveJoinRequest(let value):
            try container.encode("chat.bsky.convo.defs#logApproveJoinRequest", forKey: .type)
            try value.encode(to: encoder)
        case .chatBskyConvoDefsLogRejectJoinRequest(let value):
            try container.encode("chat.bsky.convo.defs#logRejectJoinRequest", forKey: .type)
            try value.encode(to: encoder)
        case .chatBskyConvoDefsLogOutgoingJoinRequest(let value):
            try container.encode("chat.bsky.convo.defs#logOutgoingJoinRequest", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let container):
            try container.encode(to: encoder)
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .chatBskyConvoDefsLogBeginConvo(let value):
            hasher.combine("chat.bsky.convo.defs#logBeginConvo")
            hasher.combine(value)
        case .chatBskyConvoDefsLogAcceptConvo(let value):
            hasher.combine("chat.bsky.convo.defs#logAcceptConvo")
            hasher.combine(value)
        case .chatBskyConvoDefsLogLeaveConvo(let value):
            hasher.combine("chat.bsky.convo.defs#logLeaveConvo")
            hasher.combine(value)
        case .chatBskyConvoDefsLogMuteConvo(let value):
            hasher.combine("chat.bsky.convo.defs#logMuteConvo")
            hasher.combine(value)
        case .chatBskyConvoDefsLogUnmuteConvo(let value):
            hasher.combine("chat.bsky.convo.defs#logUnmuteConvo")
            hasher.combine(value)
        case .chatBskyConvoDefsLogCreateMessage(let value):
            hasher.combine("chat.bsky.convo.defs#logCreateMessage")
            hasher.combine(value)
        case .chatBskyConvoDefsLogDeleteMessage(let value):
            hasher.combine("chat.bsky.convo.defs#logDeleteMessage")
            hasher.combine(value)
        case .chatBskyConvoDefsLogReadMessage(let value):
            hasher.combine("chat.bsky.convo.defs#logReadMessage")
            hasher.combine(value)
        case .chatBskyConvoDefsLogAddReaction(let value):
            hasher.combine("chat.bsky.convo.defs#logAddReaction")
            hasher.combine(value)
        case .chatBskyConvoDefsLogRemoveReaction(let value):
            hasher.combine("chat.bsky.convo.defs#logRemoveReaction")
            hasher.combine(value)
        case .chatBskyConvoDefsLogReadConvo(let value):
            hasher.combine("chat.bsky.convo.defs#logReadConvo")
            hasher.combine(value)
        case .chatBskyConvoDefsLogAddMember(let value):
            hasher.combine("chat.bsky.convo.defs#logAddMember")
            hasher.combine(value)
        case .chatBskyConvoDefsLogRemoveMember(let value):
            hasher.combine("chat.bsky.convo.defs#logRemoveMember")
            hasher.combine(value)
        case .chatBskyConvoDefsLogMemberJoin(let value):
            hasher.combine("chat.bsky.convo.defs#logMemberJoin")
            hasher.combine(value)
        case .chatBskyConvoDefsLogMemberLeave(let value):
            hasher.combine("chat.bsky.convo.defs#logMemberLeave")
            hasher.combine(value)
        case .chatBskyConvoDefsLogLockConvo(let value):
            hasher.combine("chat.bsky.convo.defs#logLockConvo")
            hasher.combine(value)
        case .chatBskyConvoDefsLogUnlockConvo(let value):
            hasher.combine("chat.bsky.convo.defs#logUnlockConvo")
            hasher.combine(value)
        case .chatBskyConvoDefsLogLockConvoPermanently(let value):
            hasher.combine("chat.bsky.convo.defs#logLockConvoPermanently")
            hasher.combine(value)
        case .chatBskyConvoDefsLogEditGroup(let value):
            hasher.combine("chat.bsky.convo.defs#logEditGroup")
            hasher.combine(value)
        case .chatBskyConvoDefsLogCreateJoinLink(let value):
            hasher.combine("chat.bsky.convo.defs#logCreateJoinLink")
            hasher.combine(value)
        case .chatBskyConvoDefsLogEditJoinLink(let value):
            hasher.combine("chat.bsky.convo.defs#logEditJoinLink")
            hasher.combine(value)
        case .chatBskyConvoDefsLogEnableJoinLink(let value):
            hasher.combine("chat.bsky.convo.defs#logEnableJoinLink")
            hasher.combine(value)
        case .chatBskyConvoDefsLogDisableJoinLink(let value):
            hasher.combine("chat.bsky.convo.defs#logDisableJoinLink")
            hasher.combine(value)
        case .chatBskyConvoDefsLogIncomingJoinRequest(let value):
            hasher.combine("chat.bsky.convo.defs#logIncomingJoinRequest")
            hasher.combine(value)
        case .chatBskyConvoDefsLogApproveJoinRequest(let value):
            hasher.combine("chat.bsky.convo.defs#logApproveJoinRequest")
            hasher.combine(value)
        case .chatBskyConvoDefsLogRejectJoinRequest(let value):
            hasher.combine("chat.bsky.convo.defs#logRejectJoinRequest")
            hasher.combine(value)
        case .chatBskyConvoDefsLogOutgoingJoinRequest(let value):
            hasher.combine("chat.bsky.convo.defs#logOutgoingJoinRequest")
            hasher.combine(value)
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: OutputLogsUnion, rhs: OutputLogsUnion) -> Bool {
        switch (lhs, rhs) {
        case (.chatBskyConvoDefsLogBeginConvo(let lhsValue),
              .chatBskyConvoDefsLogBeginConvo(let rhsValue)):
            return lhsValue == rhsValue
        case (.chatBskyConvoDefsLogAcceptConvo(let lhsValue),
              .chatBskyConvoDefsLogAcceptConvo(let rhsValue)):
            return lhsValue == rhsValue
        case (.chatBskyConvoDefsLogLeaveConvo(let lhsValue),
              .chatBskyConvoDefsLogLeaveConvo(let rhsValue)):
            return lhsValue == rhsValue
        case (.chatBskyConvoDefsLogMuteConvo(let lhsValue),
              .chatBskyConvoDefsLogMuteConvo(let rhsValue)):
            return lhsValue == rhsValue
        case (.chatBskyConvoDefsLogUnmuteConvo(let lhsValue),
              .chatBskyConvoDefsLogUnmuteConvo(let rhsValue)):
            return lhsValue == rhsValue
        case (.chatBskyConvoDefsLogCreateMessage(let lhsValue),
              .chatBskyConvoDefsLogCreateMessage(let rhsValue)):
            return lhsValue == rhsValue
        case (.chatBskyConvoDefsLogDeleteMessage(let lhsValue),
              .chatBskyConvoDefsLogDeleteMessage(let rhsValue)):
            return lhsValue == rhsValue
        case (.chatBskyConvoDefsLogReadMessage(let lhsValue),
              .chatBskyConvoDefsLogReadMessage(let rhsValue)):
            return lhsValue == rhsValue
        case (.chatBskyConvoDefsLogAddReaction(let lhsValue),
              .chatBskyConvoDefsLogAddReaction(let rhsValue)):
            return lhsValue == rhsValue
        case (.chatBskyConvoDefsLogRemoveReaction(let lhsValue),
              .chatBskyConvoDefsLogRemoveReaction(let rhsValue)):
            return lhsValue == rhsValue
        case (.chatBskyConvoDefsLogReadConvo(let lhsValue),
              .chatBskyConvoDefsLogReadConvo(let rhsValue)):
            return lhsValue == rhsValue
        case (.chatBskyConvoDefsLogAddMember(let lhsValue),
              .chatBskyConvoDefsLogAddMember(let rhsValue)):
            return lhsValue == rhsValue
        case (.chatBskyConvoDefsLogRemoveMember(let lhsValue),
              .chatBskyConvoDefsLogRemoveMember(let rhsValue)):
            return lhsValue == rhsValue
        case (.chatBskyConvoDefsLogMemberJoin(let lhsValue),
              .chatBskyConvoDefsLogMemberJoin(let rhsValue)):
            return lhsValue == rhsValue
        case (.chatBskyConvoDefsLogMemberLeave(let lhsValue),
              .chatBskyConvoDefsLogMemberLeave(let rhsValue)):
            return lhsValue == rhsValue
        case (.chatBskyConvoDefsLogLockConvo(let lhsValue),
              .chatBskyConvoDefsLogLockConvo(let rhsValue)):
            return lhsValue == rhsValue
        case (.chatBskyConvoDefsLogUnlockConvo(let lhsValue),
              .chatBskyConvoDefsLogUnlockConvo(let rhsValue)):
            return lhsValue == rhsValue
        case (.chatBskyConvoDefsLogLockConvoPermanently(let lhsValue),
              .chatBskyConvoDefsLogLockConvoPermanently(let rhsValue)):
            return lhsValue == rhsValue
        case (.chatBskyConvoDefsLogEditGroup(let lhsValue),
              .chatBskyConvoDefsLogEditGroup(let rhsValue)):
            return lhsValue == rhsValue
        case (.chatBskyConvoDefsLogCreateJoinLink(let lhsValue),
              .chatBskyConvoDefsLogCreateJoinLink(let rhsValue)):
            return lhsValue == rhsValue
        case (.chatBskyConvoDefsLogEditJoinLink(let lhsValue),
              .chatBskyConvoDefsLogEditJoinLink(let rhsValue)):
            return lhsValue == rhsValue
        case (.chatBskyConvoDefsLogEnableJoinLink(let lhsValue),
              .chatBskyConvoDefsLogEnableJoinLink(let rhsValue)):
            return lhsValue == rhsValue
        case (.chatBskyConvoDefsLogDisableJoinLink(let lhsValue),
              .chatBskyConvoDefsLogDisableJoinLink(let rhsValue)):
            return lhsValue == rhsValue
        case (.chatBskyConvoDefsLogIncomingJoinRequest(let lhsValue),
              .chatBskyConvoDefsLogIncomingJoinRequest(let rhsValue)):
            return lhsValue == rhsValue
        case (.chatBskyConvoDefsLogApproveJoinRequest(let lhsValue),
              .chatBskyConvoDefsLogApproveJoinRequest(let rhsValue)):
            return lhsValue == rhsValue
        case (.chatBskyConvoDefsLogRejectJoinRequest(let lhsValue),
              .chatBskyConvoDefsLogRejectJoinRequest(let rhsValue)):
            return lhsValue == rhsValue
        case (.chatBskyConvoDefsLogOutgoingJoinRequest(let lhsValue),
              .chatBskyConvoDefsLogOutgoingJoinRequest(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? OutputLogsUnion else { return false }
        return self == other
    }
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        // Create an ordered map to maintain field order
        var map = OrderedCBORMap()
        
        switch self {
        case .chatBskyConvoDefsLogBeginConvo(let value):
            map = map.adding(key: "$type", value: "chat.bsky.convo.defs#logBeginConvo")
            
            let valueDict = try value.toCBORValue()

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
            return map
        case .chatBskyConvoDefsLogAcceptConvo(let value):
            map = map.adding(key: "$type", value: "chat.bsky.convo.defs#logAcceptConvo")
            
            let valueDict = try value.toCBORValue()

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
            return map
        case .chatBskyConvoDefsLogLeaveConvo(let value):
            map = map.adding(key: "$type", value: "chat.bsky.convo.defs#logLeaveConvo")
            
            let valueDict = try value.toCBORValue()

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
            return map
        case .chatBskyConvoDefsLogMuteConvo(let value):
            map = map.adding(key: "$type", value: "chat.bsky.convo.defs#logMuteConvo")
            
            let valueDict = try value.toCBORValue()

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
            return map
        case .chatBskyConvoDefsLogUnmuteConvo(let value):
            map = map.adding(key: "$type", value: "chat.bsky.convo.defs#logUnmuteConvo")
            
            let valueDict = try value.toCBORValue()

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
            return map
        case .chatBskyConvoDefsLogCreateMessage(let value):
            map = map.adding(key: "$type", value: "chat.bsky.convo.defs#logCreateMessage")
            
            let valueDict = try value.toCBORValue()

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
            return map
        case .chatBskyConvoDefsLogDeleteMessage(let value):
            map = map.adding(key: "$type", value: "chat.bsky.convo.defs#logDeleteMessage")
            
            let valueDict = try value.toCBORValue()

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
            return map
        case .chatBskyConvoDefsLogReadMessage(let value):
            map = map.adding(key: "$type", value: "chat.bsky.convo.defs#logReadMessage")
            
            let valueDict = try value.toCBORValue()

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
            return map
        case .chatBskyConvoDefsLogAddReaction(let value):
            map = map.adding(key: "$type", value: "chat.bsky.convo.defs#logAddReaction")
            
            let valueDict = try value.toCBORValue()

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
            return map
        case .chatBskyConvoDefsLogRemoveReaction(let value):
            map = map.adding(key: "$type", value: "chat.bsky.convo.defs#logRemoveReaction")
            
            let valueDict = try value.toCBORValue()

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
            return map
        case .chatBskyConvoDefsLogReadConvo(let value):
            map = map.adding(key: "$type", value: "chat.bsky.convo.defs#logReadConvo")
            
            let valueDict = try value.toCBORValue()

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
            return map
        case .chatBskyConvoDefsLogAddMember(let value):
            map = map.adding(key: "$type", value: "chat.bsky.convo.defs#logAddMember")
            
            let valueDict = try value.toCBORValue()

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
            return map
        case .chatBskyConvoDefsLogRemoveMember(let value):
            map = map.adding(key: "$type", value: "chat.bsky.convo.defs#logRemoveMember")
            
            let valueDict = try value.toCBORValue()

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
            return map
        case .chatBskyConvoDefsLogMemberJoin(let value):
            map = map.adding(key: "$type", value: "chat.bsky.convo.defs#logMemberJoin")
            
            let valueDict = try value.toCBORValue()

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
            return map
        case .chatBskyConvoDefsLogMemberLeave(let value):
            map = map.adding(key: "$type", value: "chat.bsky.convo.defs#logMemberLeave")
            
            let valueDict = try value.toCBORValue()

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
            return map
        case .chatBskyConvoDefsLogLockConvo(let value):
            map = map.adding(key: "$type", value: "chat.bsky.convo.defs#logLockConvo")
            
            let valueDict = try value.toCBORValue()

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
            return map
        case .chatBskyConvoDefsLogUnlockConvo(let value):
            map = map.adding(key: "$type", value: "chat.bsky.convo.defs#logUnlockConvo")
            
            let valueDict = try value.toCBORValue()

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
            return map
        case .chatBskyConvoDefsLogLockConvoPermanently(let value):
            map = map.adding(key: "$type", value: "chat.bsky.convo.defs#logLockConvoPermanently")
            
            let valueDict = try value.toCBORValue()

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
            return map
        case .chatBskyConvoDefsLogEditGroup(let value):
            map = map.adding(key: "$type", value: "chat.bsky.convo.defs#logEditGroup")
            
            let valueDict = try value.toCBORValue()

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
            return map
        case .chatBskyConvoDefsLogCreateJoinLink(let value):
            map = map.adding(key: "$type", value: "chat.bsky.convo.defs#logCreateJoinLink")
            
            let valueDict = try value.toCBORValue()

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
            return map
        case .chatBskyConvoDefsLogEditJoinLink(let value):
            map = map.adding(key: "$type", value: "chat.bsky.convo.defs#logEditJoinLink")
            
            let valueDict = try value.toCBORValue()

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
            return map
        case .chatBskyConvoDefsLogEnableJoinLink(let value):
            map = map.adding(key: "$type", value: "chat.bsky.convo.defs#logEnableJoinLink")
            
            let valueDict = try value.toCBORValue()

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
            return map
        case .chatBskyConvoDefsLogDisableJoinLink(let value):
            map = map.adding(key: "$type", value: "chat.bsky.convo.defs#logDisableJoinLink")
            
            let valueDict = try value.toCBORValue()

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
            return map
        case .chatBskyConvoDefsLogIncomingJoinRequest(let value):
            map = map.adding(key: "$type", value: "chat.bsky.convo.defs#logIncomingJoinRequest")
            
            let valueDict = try value.toCBORValue()

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
            return map
        case .chatBskyConvoDefsLogApproveJoinRequest(let value):
            map = map.adding(key: "$type", value: "chat.bsky.convo.defs#logApproveJoinRequest")
            
            let valueDict = try value.toCBORValue()

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
            return map
        case .chatBskyConvoDefsLogRejectJoinRequest(let value):
            map = map.adding(key: "$type", value: "chat.bsky.convo.defs#logRejectJoinRequest")
            
            let valueDict = try value.toCBORValue()

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
            return map
        case .chatBskyConvoDefsLogOutgoingJoinRequest(let value):
            map = map.adding(key: "$type", value: "chat.bsky.convo.defs#logOutgoingJoinRequest")
            
            let valueDict = try value.toCBORValue()

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
            return map
        case .unexpected(let container):
            return try container.toCBORValue()
        }
    }
}


}



extension ATProtoClient.Chat.Bsky.Convo {
    // MARK: - getLog

    /// 
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getLog(input: ChatBskyConvoGetLog.Parameters) async throws -> (responseCode: Int, data: ChatBskyConvoGetLog.Output?) {
        let endpoint = "chat.bsky.convo.getLog"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "chat.bsky.convo.getLog")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        // Only validate Content-Type and decode on success. Error responses
        // (4xx/5xx) may have missing or different Content-Type headers and
        // are handled via the status code / structured error parser below.
        if (200...299).contains(responseCode) {
            
            guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
                throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
            }

            if !contentType.lowercased().contains("application/json") {
                throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
            }
            

            do {
                
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(ChatBskyConvoGetLog.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for chat.bsky.convo.getLog: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

