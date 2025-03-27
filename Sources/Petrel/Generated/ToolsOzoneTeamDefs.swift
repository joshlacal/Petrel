import Foundation



// lexicon: 1, id: tools.ozone.team.defs


public struct ToolsOzoneTeamDefs { 

    public static let typeIdentifier = "tools.ozone.team.defs"
        
public struct Member: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "tools.ozone.team.defs#member"
            public let did: String
            public let disabled: Bool?
            public let profile: AppBskyActorDefs.ProfileViewDetailed?
            public let createdAt: ATProtocolDate?
            public let updatedAt: ATProtocolDate?
            public let lastUpdatedBy: String?
            public let role: String

        // Standard initializer
        public init(
            did: String, disabled: Bool?, profile: AppBskyActorDefs.ProfileViewDetailed?, createdAt: ATProtocolDate?, updatedAt: ATProtocolDate?, lastUpdatedBy: String?, role: String
        ) {
            
            self.did = did
            self.disabled = disabled
            self.profile = profile
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.lastUpdatedBy = lastUpdatedBy
            self.role = role
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.did = try container.decode(String.self, forKey: .did)
                
            } catch {
                LogManager.logError("Decoding error for property 'did': \(error)")
                throw error
            }
            do {
                
                self.disabled = try container.decodeIfPresent(Bool.self, forKey: .disabled)
                
            } catch {
                LogManager.logError("Decoding error for property 'disabled': \(error)")
                throw error
            }
            do {
                
                self.profile = try container.decodeIfPresent(AppBskyActorDefs.ProfileViewDetailed.self, forKey: .profile)
                
            } catch {
                LogManager.logError("Decoding error for property 'profile': \(error)")
                throw error
            }
            do {
                
                self.createdAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .createdAt)
                
            } catch {
                LogManager.logError("Decoding error for property 'createdAt': \(error)")
                throw error
            }
            do {
                
                self.updatedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .updatedAt)
                
            } catch {
                LogManager.logError("Decoding error for property 'updatedAt': \(error)")
                throw error
            }
            do {
                
                self.lastUpdatedBy = try container.decodeIfPresent(String.self, forKey: .lastUpdatedBy)
                
            } catch {
                LogManager.logError("Decoding error for property 'lastUpdatedBy': \(error)")
                throw error
            }
            do {
                
                self.role = try container.decode(String.self, forKey: .role)
                
            } catch {
                LogManager.logError("Decoding error for property 'role': \(error)")
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(did, forKey: .did)
            
            
            if let value = disabled {
                
                try container.encode(value, forKey: .disabled)
                
            }
            
            
            if let value = profile {
                
                try container.encode(value, forKey: .profile)
                
            }
            
            
            if let value = createdAt {
                
                try container.encode(value, forKey: .createdAt)
                
            }
            
            
            if let value = updatedAt {
                
                try container.encode(value, forKey: .updatedAt)
                
            }
            
            
            if let value = lastUpdatedBy {
                
                try container.encode(value, forKey: .lastUpdatedBy)
                
            }
            
            
            try container.encode(role, forKey: .role)
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(did)
            if let value = disabled {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = profile {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = createdAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = updatedAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = lastUpdatedBy {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(role)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            if self.did != other.did {
                return false
            }
            
            
            if disabled != other.disabled {
                return false
            }
            
            
            if profile != other.profile {
                return false
            }
            
            
            if createdAt != other.createdAt {
                return false
            }
            
            
            if updatedAt != other.updatedAt {
                return false
            }
            
            
            if lastUpdatedBy != other.lastUpdatedBy {
                return false
            }
            
            
            if self.role != other.role {
                return false
            }
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
            case disabled
            case profile
            case createdAt
            case updatedAt
            case lastUpdatedBy
            case role
        }
    }



}


                           
