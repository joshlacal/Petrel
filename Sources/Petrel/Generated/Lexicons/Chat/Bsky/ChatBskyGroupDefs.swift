import Foundation



// lexicon: 1, id: chat.bsky.group.defs


public struct ChatBskyGroupDefs { 

    public static let typeIdentifier = "chat.bsky.group.defs"
        
public struct JoinLinkView: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "chat.bsky.group.defs#joinLinkView"
            public let code: String
            public let enabledStatus: LinkEnabledStatus
            public let requireApproval: Bool
            public let joinRule: JoinRule
            public let createdAt: ATProtocolDate

        public init(
            code: String, enabledStatus: LinkEnabledStatus, requireApproval: Bool, joinRule: JoinRule, createdAt: ATProtocolDate
        ) {
            self.code = code
            self.enabledStatus = enabledStatus
            self.requireApproval = requireApproval
            self.joinRule = joinRule
            self.createdAt = createdAt
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.code = try container.decode(String.self, forKey: .code)
            } catch {
                LogManager.logError("Decoding error for required property 'code': \(error)")
                throw error
            }
            do {
                self.enabledStatus = try container.decode(LinkEnabledStatus.self, forKey: .enabledStatus)
            } catch {
                LogManager.logError("Decoding error for required property 'enabledStatus': \(error)")
                throw error
            }
            do {
                self.requireApproval = try container.decode(Bool.self, forKey: .requireApproval)
            } catch {
                LogManager.logError("Decoding error for required property 'requireApproval': \(error)")
                throw error
            }
            do {
                self.joinRule = try container.decode(JoinRule.self, forKey: .joinRule)
            } catch {
                LogManager.logError("Decoding error for required property 'joinRule': \(error)")
                throw error
            }
            do {
                self.createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
            } catch {
                LogManager.logError("Decoding error for required property 'createdAt': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(code, forKey: .code)
            try container.encode(enabledStatus, forKey: .enabledStatus)
            try container.encode(requireApproval, forKey: .requireApproval)
            try container.encode(joinRule, forKey: .joinRule)
            try container.encode(createdAt, forKey: .createdAt)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(code)
            hasher.combine(enabledStatus)
            hasher.combine(requireApproval)
            hasher.combine(joinRule)
            hasher.combine(createdAt)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if code != other.code {
                return false
            }
            if enabledStatus != other.enabledStatus {
                return false
            }
            if requireApproval != other.requireApproval {
                return false
            }
            if joinRule != other.joinRule {
                return false
            }
            if createdAt != other.createdAt {
                return false
            }
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let codeValue = try code.toCBORValue()
            map = map.adding(key: "code", value: codeValue)
            let enabledStatusValue = try enabledStatus.toCBORValue()
            map = map.adding(key: "enabledStatus", value: enabledStatusValue)
            let requireApprovalValue = try requireApproval.toCBORValue()
            map = map.adding(key: "requireApproval", value: requireApprovalValue)
            let joinRuleValue = try joinRule.toCBORValue()
            map = map.adding(key: "joinRule", value: joinRuleValue)
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case code
            case enabledStatus
            case requireApproval
            case joinRule
            case createdAt
        }
    }
        
public struct GroupPublicView: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "chat.bsky.group.defs#groupPublicView"
            public let name: String
            public let owner: ChatBskyActorDefs.ProfileViewBasic
            public let memberCount: Int
            public let requireApproval: Bool

        public init(
            name: String, owner: ChatBskyActorDefs.ProfileViewBasic, memberCount: Int, requireApproval: Bool
        ) {
            self.name = name
            self.owner = owner
            self.memberCount = memberCount
            self.requireApproval = requireApproval
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.name = try container.decode(String.self, forKey: .name)
            } catch {
                LogManager.logError("Decoding error for required property 'name': \(error)")
                throw error
            }
            do {
                self.owner = try container.decode(ChatBskyActorDefs.ProfileViewBasic.self, forKey: .owner)
            } catch {
                LogManager.logError("Decoding error for required property 'owner': \(error)")
                throw error
            }
            do {
                self.memberCount = try container.decode(Int.self, forKey: .memberCount)
            } catch {
                LogManager.logError("Decoding error for required property 'memberCount': \(error)")
                throw error
            }
            do {
                self.requireApproval = try container.decode(Bool.self, forKey: .requireApproval)
            } catch {
                LogManager.logError("Decoding error for required property 'requireApproval': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(name, forKey: .name)
            try container.encode(owner, forKey: .owner)
            try container.encode(memberCount, forKey: .memberCount)
            try container.encode(requireApproval, forKey: .requireApproval)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(name)
            hasher.combine(owner)
            hasher.combine(memberCount)
            hasher.combine(requireApproval)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if name != other.name {
                return false
            }
            if owner != other.owner {
                return false
            }
            if memberCount != other.memberCount {
                return false
            }
            if requireApproval != other.requireApproval {
                return false
            }
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let nameValue = try name.toCBORValue()
            map = map.adding(key: "name", value: nameValue)
            let ownerValue = try owner.toCBORValue()
            map = map.adding(key: "owner", value: ownerValue)
            let memberCountValue = try memberCount.toCBORValue()
            map = map.adding(key: "memberCount", value: memberCountValue)
            let requireApprovalValue = try requireApproval.toCBORValue()
            map = map.adding(key: "requireApproval", value: requireApprovalValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case name
            case owner
            case memberCount
            case requireApproval
        }
    }
        
public struct JoinRequestView: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "chat.bsky.group.defs#joinRequestView"
            public let convoId: String
            public let requestedBy: ChatBskyActorDefs.ProfileViewBasic
            public let requestedAt: ATProtocolDate

        public init(
            convoId: String, requestedBy: ChatBskyActorDefs.ProfileViewBasic, requestedAt: ATProtocolDate
        ) {
            self.convoId = convoId
            self.requestedBy = requestedBy
            self.requestedAt = requestedAt
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                throw error
            }
            do {
                self.requestedBy = try container.decode(ChatBskyActorDefs.ProfileViewBasic.self, forKey: .requestedBy)
            } catch {
                LogManager.logError("Decoding error for required property 'requestedBy': \(error)")
                throw error
            }
            do {
                self.requestedAt = try container.decode(ATProtocolDate.self, forKey: .requestedAt)
            } catch {
                LogManager.logError("Decoding error for required property 'requestedAt': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(requestedBy, forKey: .requestedBy)
            try container.encode(requestedAt, forKey: .requestedAt)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(convoId)
            hasher.combine(requestedBy)
            hasher.combine(requestedAt)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if convoId != other.convoId {
                return false
            }
            if requestedBy != other.requestedBy {
                return false
            }
            if requestedAt != other.requestedAt {
                return false
            }
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let requestedByValue = try requestedBy.toCBORValue()
            map = map.adding(key: "requestedBy", value: requestedByValue)
            let requestedAtValue = try requestedAt.toCBORValue()
            map = map.adding(key: "requestedAt", value: requestedAtValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case convoId
            case requestedBy
            case requestedAt
        }
    }



public struct LinkEnabledStatus: Codable, ATProtocolCodable, ATProtocolValue {
            public let rawValue: String
            
            // Predefined constants
            // 
            public static let enabled = LinkEnabledStatus(rawValue: "enabled")
            // 
            public static let disabled = LinkEnabledStatus(rawValue: "disabled")
            
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
                guard let otherValue = other as? LinkEnabledStatus else { return false }
                return self.rawValue == otherValue.rawValue
            }
            
            // DAGCBOR encoding with field ordering
            public func toCBORValue() throws -> Any {
                // For string-based enum types, we return the raw string value directly
                return rawValue
            }
            
            // Provide allCases-like functionality
            public static var predefinedValues: [LinkEnabledStatus] {
                return [
                    .enabled,
                    .disabled,
                ]
            }
        }


public struct JoinRule: Codable, ATProtocolCodable, ATProtocolValue {
            public let rawValue: String
            
            // Predefined constants
            // 
            public static let anyone = JoinRule(rawValue: "anyone")
            // 
            public static let followedbyowner = JoinRule(rawValue: "followedByOwner")
            
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
                guard let otherValue = other as? JoinRule else { return false }
                return self.rawValue == otherValue.rawValue
            }
            
            // DAGCBOR encoding with field ordering
            public func toCBORValue() throws -> Any {
                // For string-based enum types, we return the raw string value directly
                return rawValue
            }
            
            // Provide allCases-like functionality
            public static var predefinedValues: [JoinRule] {
                return [
                    .anyone,
                    .followedbyowner,
                ]
            }
        }


}


                           

