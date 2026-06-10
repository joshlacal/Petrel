import Foundation

// lexicon: 1, id: chat.bsky.convo.getLog

public enum ChatBskyConvoGetLog {
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

        /// Standard public initializer
        public init(
            cursor: String? = nil,

            logs: [OutputLogsUnion]

        ) {
            self.cursor = cursor

            self.logs = logs
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            cursor = try container.decodeIfPresent(String.self, forKey: .cursor)

            logs = try container.decode([OutputLogsUnion].self, forKey: .logs)
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
        case chatBskyConvoDefsLogWithdrawIncomingJoinRequest(ChatBskyConvoDefs.LogWithdrawIncomingJoinRequest)
        case chatBskyConvoDefsLogWithdrawOutgoingJoinRequest(ChatBskyConvoDefs.LogWithdrawOutgoingJoinRequest)
        case chatBskyConvoDefsLogReadJoinRequests(ChatBskyConvoDefs.LogReadJoinRequests)
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

        public init(_ value: ChatBskyConvoDefs.LogWithdrawIncomingJoinRequest) {
            self = .chatBskyConvoDefsLogWithdrawIncomingJoinRequest(value)
        }

        public init(_ value: ChatBskyConvoDefs.LogWithdrawOutgoingJoinRequest) {
            self = .chatBskyConvoDefsLogWithdrawOutgoingJoinRequest(value)
        }

        public init(_ value: ChatBskyConvoDefs.LogReadJoinRequests) {
            self = .chatBskyConvoDefsLogReadJoinRequests(value)
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
            case "chat.bsky.convo.defs#logWithdrawIncomingJoinRequest":
                let value = try ChatBskyConvoDefs.LogWithdrawIncomingJoinRequest(from: decoder)
                self = .chatBskyConvoDefsLogWithdrawIncomingJoinRequest(value)
            case "chat.bsky.convo.defs#logWithdrawOutgoingJoinRequest":
                let value = try ChatBskyConvoDefs.LogWithdrawOutgoingJoinRequest(from: decoder)
                self = .chatBskyConvoDefsLogWithdrawOutgoingJoinRequest(value)
            case "chat.bsky.convo.defs#logReadJoinRequests":
                let value = try ChatBskyConvoDefs.LogReadJoinRequests(from: decoder)
                self = .chatBskyConvoDefsLogReadJoinRequests(value)
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .chatBskyConvoDefsLogBeginConvo(value):
                try container.encode("chat.bsky.convo.defs#logBeginConvo", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogAcceptConvo(value):
                try container.encode("chat.bsky.convo.defs#logAcceptConvo", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogLeaveConvo(value):
                try container.encode("chat.bsky.convo.defs#logLeaveConvo", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogMuteConvo(value):
                try container.encode("chat.bsky.convo.defs#logMuteConvo", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogUnmuteConvo(value):
                try container.encode("chat.bsky.convo.defs#logUnmuteConvo", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogCreateMessage(value):
                try container.encode("chat.bsky.convo.defs#logCreateMessage", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogDeleteMessage(value):
                try container.encode("chat.bsky.convo.defs#logDeleteMessage", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogReadMessage(value):
                try container.encode("chat.bsky.convo.defs#logReadMessage", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogAddReaction(value):
                try container.encode("chat.bsky.convo.defs#logAddReaction", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogRemoveReaction(value):
                try container.encode("chat.bsky.convo.defs#logRemoveReaction", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogReadConvo(value):
                try container.encode("chat.bsky.convo.defs#logReadConvo", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogAddMember(value):
                try container.encode("chat.bsky.convo.defs#logAddMember", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogRemoveMember(value):
                try container.encode("chat.bsky.convo.defs#logRemoveMember", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogMemberJoin(value):
                try container.encode("chat.bsky.convo.defs#logMemberJoin", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogMemberLeave(value):
                try container.encode("chat.bsky.convo.defs#logMemberLeave", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogLockConvo(value):
                try container.encode("chat.bsky.convo.defs#logLockConvo", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogUnlockConvo(value):
                try container.encode("chat.bsky.convo.defs#logUnlockConvo", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogLockConvoPermanently(value):
                try container.encode("chat.bsky.convo.defs#logLockConvoPermanently", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogEditGroup(value):
                try container.encode("chat.bsky.convo.defs#logEditGroup", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogCreateJoinLink(value):
                try container.encode("chat.bsky.convo.defs#logCreateJoinLink", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogEditJoinLink(value):
                try container.encode("chat.bsky.convo.defs#logEditJoinLink", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogEnableJoinLink(value):
                try container.encode("chat.bsky.convo.defs#logEnableJoinLink", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogDisableJoinLink(value):
                try container.encode("chat.bsky.convo.defs#logDisableJoinLink", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogIncomingJoinRequest(value):
                try container.encode("chat.bsky.convo.defs#logIncomingJoinRequest", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogApproveJoinRequest(value):
                try container.encode("chat.bsky.convo.defs#logApproveJoinRequest", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogRejectJoinRequest(value):
                try container.encode("chat.bsky.convo.defs#logRejectJoinRequest", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogOutgoingJoinRequest(value):
                try container.encode("chat.bsky.convo.defs#logOutgoingJoinRequest", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogWithdrawIncomingJoinRequest(value):
                try container.encode("chat.bsky.convo.defs#logWithdrawIncomingJoinRequest", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogWithdrawOutgoingJoinRequest(value):
                try container.encode("chat.bsky.convo.defs#logWithdrawOutgoingJoinRequest", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyConvoDefsLogReadJoinRequests(value):
                try container.encode("chat.bsky.convo.defs#logReadJoinRequests", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .chatBskyConvoDefsLogBeginConvo(value):
                hasher.combine("chat.bsky.convo.defs#logBeginConvo")
                hasher.combine(value)
            case let .chatBskyConvoDefsLogAcceptConvo(value):
                hasher.combine("chat.bsky.convo.defs#logAcceptConvo")
                hasher.combine(value)
            case let .chatBskyConvoDefsLogLeaveConvo(value):
                hasher.combine("chat.bsky.convo.defs#logLeaveConvo")
                hasher.combine(value)
            case let .chatBskyConvoDefsLogMuteConvo(value):
                hasher.combine("chat.bsky.convo.defs#logMuteConvo")
                hasher.combine(value)
            case let .chatBskyConvoDefsLogUnmuteConvo(value):
                hasher.combine("chat.bsky.convo.defs#logUnmuteConvo")
                hasher.combine(value)
            case let .chatBskyConvoDefsLogCreateMessage(value):
                hasher.combine("chat.bsky.convo.defs#logCreateMessage")
                hasher.combine(value)
            case let .chatBskyConvoDefsLogDeleteMessage(value):
                hasher.combine("chat.bsky.convo.defs#logDeleteMessage")
                hasher.combine(value)
            case let .chatBskyConvoDefsLogReadMessage(value):
                hasher.combine("chat.bsky.convo.defs#logReadMessage")
                hasher.combine(value)
            case let .chatBskyConvoDefsLogAddReaction(value):
                hasher.combine("chat.bsky.convo.defs#logAddReaction")
                hasher.combine(value)
            case let .chatBskyConvoDefsLogRemoveReaction(value):
                hasher.combine("chat.bsky.convo.defs#logRemoveReaction")
                hasher.combine(value)
            case let .chatBskyConvoDefsLogReadConvo(value):
                hasher.combine("chat.bsky.convo.defs#logReadConvo")
                hasher.combine(value)
            case let .chatBskyConvoDefsLogAddMember(value):
                hasher.combine("chat.bsky.convo.defs#logAddMember")
                hasher.combine(value)
            case let .chatBskyConvoDefsLogRemoveMember(value):
                hasher.combine("chat.bsky.convo.defs#logRemoveMember")
                hasher.combine(value)
            case let .chatBskyConvoDefsLogMemberJoin(value):
                hasher.combine("chat.bsky.convo.defs#logMemberJoin")
                hasher.combine(value)
            case let .chatBskyConvoDefsLogMemberLeave(value):
                hasher.combine("chat.bsky.convo.defs#logMemberLeave")
                hasher.combine(value)
            case let .chatBskyConvoDefsLogLockConvo(value):
                hasher.combine("chat.bsky.convo.defs#logLockConvo")
                hasher.combine(value)
            case let .chatBskyConvoDefsLogUnlockConvo(value):
                hasher.combine("chat.bsky.convo.defs#logUnlockConvo")
                hasher.combine(value)
            case let .chatBskyConvoDefsLogLockConvoPermanently(value):
                hasher.combine("chat.bsky.convo.defs#logLockConvoPermanently")
                hasher.combine(value)
            case let .chatBskyConvoDefsLogEditGroup(value):
                hasher.combine("chat.bsky.convo.defs#logEditGroup")
                hasher.combine(value)
            case let .chatBskyConvoDefsLogCreateJoinLink(value):
                hasher.combine("chat.bsky.convo.defs#logCreateJoinLink")
                hasher.combine(value)
            case let .chatBskyConvoDefsLogEditJoinLink(value):
                hasher.combine("chat.bsky.convo.defs#logEditJoinLink")
                hasher.combine(value)
            case let .chatBskyConvoDefsLogEnableJoinLink(value):
                hasher.combine("chat.bsky.convo.defs#logEnableJoinLink")
                hasher.combine(value)
            case let .chatBskyConvoDefsLogDisableJoinLink(value):
                hasher.combine("chat.bsky.convo.defs#logDisableJoinLink")
                hasher.combine(value)
            case let .chatBskyConvoDefsLogIncomingJoinRequest(value):
                hasher.combine("chat.bsky.convo.defs#logIncomingJoinRequest")
                hasher.combine(value)
            case let .chatBskyConvoDefsLogApproveJoinRequest(value):
                hasher.combine("chat.bsky.convo.defs#logApproveJoinRequest")
                hasher.combine(value)
            case let .chatBskyConvoDefsLogRejectJoinRequest(value):
                hasher.combine("chat.bsky.convo.defs#logRejectJoinRequest")
                hasher.combine(value)
            case let .chatBskyConvoDefsLogOutgoingJoinRequest(value):
                hasher.combine("chat.bsky.convo.defs#logOutgoingJoinRequest")
                hasher.combine(value)
            case let .chatBskyConvoDefsLogWithdrawIncomingJoinRequest(value):
                hasher.combine("chat.bsky.convo.defs#logWithdrawIncomingJoinRequest")
                hasher.combine(value)
            case let .chatBskyConvoDefsLogWithdrawOutgoingJoinRequest(value):
                hasher.combine("chat.bsky.convo.defs#logWithdrawOutgoingJoinRequest")
                hasher.combine(value)
            case let .chatBskyConvoDefsLogReadJoinRequests(value):
                hasher.combine("chat.bsky.convo.defs#logReadJoinRequests")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: OutputLogsUnion, rhs: OutputLogsUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .chatBskyConvoDefsLogBeginConvo(lhsValue),
                .chatBskyConvoDefsLogBeginConvo(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsLogAcceptConvo(lhsValue),
                .chatBskyConvoDefsLogAcceptConvo(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsLogLeaveConvo(lhsValue),
                .chatBskyConvoDefsLogLeaveConvo(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsLogMuteConvo(lhsValue),
                .chatBskyConvoDefsLogMuteConvo(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsLogUnmuteConvo(lhsValue),
                .chatBskyConvoDefsLogUnmuteConvo(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsLogCreateMessage(lhsValue),
                .chatBskyConvoDefsLogCreateMessage(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsLogDeleteMessage(lhsValue),
                .chatBskyConvoDefsLogDeleteMessage(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsLogReadMessage(lhsValue),
                .chatBskyConvoDefsLogReadMessage(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsLogAddReaction(lhsValue),
                .chatBskyConvoDefsLogAddReaction(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsLogRemoveReaction(lhsValue),
                .chatBskyConvoDefsLogRemoveReaction(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsLogReadConvo(lhsValue),
                .chatBskyConvoDefsLogReadConvo(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsLogAddMember(lhsValue),
                .chatBskyConvoDefsLogAddMember(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsLogRemoveMember(lhsValue),
                .chatBskyConvoDefsLogRemoveMember(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsLogMemberJoin(lhsValue),
                .chatBskyConvoDefsLogMemberJoin(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsLogMemberLeave(lhsValue),
                .chatBskyConvoDefsLogMemberLeave(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsLogLockConvo(lhsValue),
                .chatBskyConvoDefsLogLockConvo(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsLogUnlockConvo(lhsValue),
                .chatBskyConvoDefsLogUnlockConvo(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsLogLockConvoPermanently(lhsValue),
                .chatBskyConvoDefsLogLockConvoPermanently(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsLogEditGroup(lhsValue),
                .chatBskyConvoDefsLogEditGroup(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsLogCreateJoinLink(lhsValue),
                .chatBskyConvoDefsLogCreateJoinLink(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsLogEditJoinLink(lhsValue),
                .chatBskyConvoDefsLogEditJoinLink(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsLogEnableJoinLink(lhsValue),
                .chatBskyConvoDefsLogEnableJoinLink(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsLogDisableJoinLink(lhsValue),
                .chatBskyConvoDefsLogDisableJoinLink(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsLogIncomingJoinRequest(lhsValue),
                .chatBskyConvoDefsLogIncomingJoinRequest(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsLogApproveJoinRequest(lhsValue),
                .chatBskyConvoDefsLogApproveJoinRequest(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsLogRejectJoinRequest(lhsValue),
                .chatBskyConvoDefsLogRejectJoinRequest(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsLogOutgoingJoinRequest(lhsValue),
                .chatBskyConvoDefsLogOutgoingJoinRequest(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsLogWithdrawIncomingJoinRequest(lhsValue),
                .chatBskyConvoDefsLogWithdrawIncomingJoinRequest(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsLogWithdrawOutgoingJoinRequest(lhsValue),
                .chatBskyConvoDefsLogWithdrawOutgoingJoinRequest(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyConvoDefsLogReadJoinRequests(lhsValue),
                .chatBskyConvoDefsLogReadJoinRequests(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? OutputLogsUnion else { return false }
            return self == other
        }

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .chatBskyConvoDefsLogBeginConvo(value):
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
            case let .chatBskyConvoDefsLogAcceptConvo(value):
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
            case let .chatBskyConvoDefsLogLeaveConvo(value):
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
            case let .chatBskyConvoDefsLogMuteConvo(value):
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
            case let .chatBskyConvoDefsLogUnmuteConvo(value):
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
            case let .chatBskyConvoDefsLogCreateMessage(value):
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
            case let .chatBskyConvoDefsLogDeleteMessage(value):
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
            case let .chatBskyConvoDefsLogReadMessage(value):
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
            case let .chatBskyConvoDefsLogAddReaction(value):
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
            case let .chatBskyConvoDefsLogRemoveReaction(value):
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
            case let .chatBskyConvoDefsLogReadConvo(value):
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
            case let .chatBskyConvoDefsLogAddMember(value):
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
            case let .chatBskyConvoDefsLogRemoveMember(value):
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
            case let .chatBskyConvoDefsLogMemberJoin(value):
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
            case let .chatBskyConvoDefsLogMemberLeave(value):
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
            case let .chatBskyConvoDefsLogLockConvo(value):
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
            case let .chatBskyConvoDefsLogUnlockConvo(value):
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
            case let .chatBskyConvoDefsLogLockConvoPermanently(value):
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
            case let .chatBskyConvoDefsLogEditGroup(value):
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
            case let .chatBskyConvoDefsLogCreateJoinLink(value):
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
            case let .chatBskyConvoDefsLogEditJoinLink(value):
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
            case let .chatBskyConvoDefsLogEnableJoinLink(value):
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
            case let .chatBskyConvoDefsLogDisableJoinLink(value):
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
            case let .chatBskyConvoDefsLogIncomingJoinRequest(value):
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
            case let .chatBskyConvoDefsLogApproveJoinRequest(value):
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
            case let .chatBskyConvoDefsLogRejectJoinRequest(value):
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
            case let .chatBskyConvoDefsLogOutgoingJoinRequest(value):
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
            case let .chatBskyConvoDefsLogWithdrawIncomingJoinRequest(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#logWithdrawIncomingJoinRequest")

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
            case let .chatBskyConvoDefsLogWithdrawOutgoingJoinRequest(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#logWithdrawOutgoingJoinRequest")

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
            case let .chatBskyConvoDefsLogReadJoinRequests(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#logReadJoinRequests")

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
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }
    }
}

public extension ATProtoClient.Chat.Bsky.Convo {
    // MARK: - getLog

    ///
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getLog(input: ChatBskyConvoGetLog.Parameters) async throws -> (responseCode: Int, data: ChatBskyConvoGetLog.Output?) {
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
        if (200 ... 299).contains(responseCode) {
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
