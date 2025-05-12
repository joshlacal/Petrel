import Foundation



// lexicon: 1, id: com.atproto.admin.updateSubjectStatus


public struct ComAtprotoAdminUpdateSubjectStatus { 

    public static let typeIdentifier = "com.atproto.admin.updateSubjectStatus"
public struct Input: ATProtocolCodable {
            public let subject: InputSubjectUnion
            public let takedown: ComAtprotoAdminDefs.StatusAttr?
            public let deactivated: ComAtprotoAdminDefs.StatusAttr?

            // Standard public initializer
            public init(subject: InputSubjectUnion, takedown: ComAtprotoAdminDefs.StatusAttr? = nil, deactivated: ComAtprotoAdminDefs.StatusAttr? = nil) {
                self.subject = subject
                self.takedown = takedown
                self.deactivated = deactivated
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.subject = try container.decode(InputSubjectUnion.self, forKey: .subject)
                
                
                self.takedown = try container.decodeIfPresent(ComAtprotoAdminDefs.StatusAttr.self, forKey: .takedown)
                
                
                self.deactivated = try container.decodeIfPresent(ComAtprotoAdminDefs.StatusAttr.self, forKey: .deactivated)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(subject, forKey: .subject)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(takedown, forKey: .takedown)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(deactivated, forKey: .deactivated)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case subject
                case takedown
                case deactivated
            }
            
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()

                
                
                let subjectValue = try subject.toCBORValue()
                map = map.adding(key: "subject", value: subjectValue)
                
                
                
                if let value = takedown {
                    // Encode optional property even if it's an empty array for CBOR
                    let takedownValue = try value.toCBORValue()
                    map = map.adding(key: "takedown", value: takedownValue)
                }
                
                
                
                if let value = deactivated {
                    // Encode optional property even if it's an empty array for CBOR
                    let deactivatedValue = try value.toCBORValue()
                    map = map.adding(key: "deactivated", value: deactivatedValue)
                }
                
                

                return map
            }
        }
    
public struct Output: ATProtocolCodable {
        
        
        public let subject: OutputSubjectUnion
        
        public let takedown: ComAtprotoAdminDefs.StatusAttr?
        
        
        
        // Standard public initializer
        public init(
            
            subject: OutputSubjectUnion,
            
            takedown: ComAtprotoAdminDefs.StatusAttr? = nil
            
            
        ) {
            
            self.subject = subject
            
            self.takedown = takedown
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.subject = try container.decode(OutputSubjectUnion.self, forKey: .subject)
            
            
            self.takedown = try container.decodeIfPresent(ComAtprotoAdminDefs.StatusAttr.self, forKey: .takedown)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            try container.encode(subject, forKey: .subject)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(takedown, forKey: .takedown)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let subjectValue = try subject.toCBORValue()
            map = map.adding(key: "subject", value: subjectValue)
            
            
            
            if let value = takedown {
                // Encode optional property even if it's an empty array for CBOR
                let takedownValue = try value.toCBORValue()
                map = map.adding(key: "takedown", value: takedownValue)
            }
            
            

            return map
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case subject
            case takedown
            
        }
    }






public enum InputSubjectUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
    case comAtprotoAdminDefsRepoRef(ComAtprotoAdminDefs.RepoRef)
    case comAtprotoRepoStrongRef(ComAtprotoRepoStrongRef)
    case comAtprotoAdminDefsRepoBlobRef(ComAtprotoAdminDefs.RepoBlobRef)
    case unexpected(ATProtocolValueContainer)
    
    public init(_ value: ComAtprotoAdminDefs.RepoRef) {
        self = .comAtprotoAdminDefsRepoRef(value)
    }
    public init(_ value: ComAtprotoRepoStrongRef) {
        self = .comAtprotoRepoStrongRef(value)
    }
    public init(_ value: ComAtprotoAdminDefs.RepoBlobRef) {
        self = .comAtprotoAdminDefsRepoBlobRef(value)
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
        case "com.atproto.admin.defs#repoBlobRef":
            let value = try ComAtprotoAdminDefs.RepoBlobRef(from: decoder)
            self = .comAtprotoAdminDefsRepoBlobRef(value)
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
        case .comAtprotoAdminDefsRepoBlobRef(let value):
            try container.encode("com.atproto.admin.defs#repoBlobRef", forKey: .type)
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
        case .comAtprotoAdminDefsRepoBlobRef(let value):
            hasher.combine("com.atproto.admin.defs#repoBlobRef")
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
        case (.comAtprotoAdminDefsRepoBlobRef(let lhsValue),
              .comAtprotoAdminDefsRepoBlobRef(let rhsValue)):
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
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        // Create an ordered map to maintain field order
        var map = OrderedCBORMap()
        
        switch self {
        case .comAtprotoAdminDefsRepoRef(let value):
            map = map.adding(key: "$type", value: "com.atproto.admin.defs#repoRef")
            
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
        case .comAtprotoRepoStrongRef(let value):
            map = map.adding(key: "$type", value: "com.atproto.repo.strongRef")
            
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
        case .comAtprotoAdminDefsRepoBlobRef(let value):
            map = map.adding(key: "$type", value: "com.atproto.admin.defs#repoBlobRef")
            
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
    
    /// Property that indicates if this enum contains pending data that needs loading
    public var hasPendingData: Bool {
        switch self {
        
        case .comAtprotoAdminDefsRepoRef(let value):
            return value.hasPendingData
        case .comAtprotoRepoStrongRef(let value):
            return value.hasPendingData
        case .comAtprotoAdminDefsRepoBlobRef(let value):
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
        case .comAtprotoAdminDefsRepoBlobRef(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .comAtprotoAdminDefsRepoBlobRef(value)
        case .unexpected:
            // Nothing to load for unexpected values
            break
        }
    }
}




public enum OutputSubjectUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
    case comAtprotoAdminDefsRepoRef(ComAtprotoAdminDefs.RepoRef)
    case comAtprotoRepoStrongRef(ComAtprotoRepoStrongRef)
    case comAtprotoAdminDefsRepoBlobRef(ComAtprotoAdminDefs.RepoBlobRef)
    case unexpected(ATProtocolValueContainer)
    
    public init(_ value: ComAtprotoAdminDefs.RepoRef) {
        self = .comAtprotoAdminDefsRepoRef(value)
    }
    public init(_ value: ComAtprotoRepoStrongRef) {
        self = .comAtprotoRepoStrongRef(value)
    }
    public init(_ value: ComAtprotoAdminDefs.RepoBlobRef) {
        self = .comAtprotoAdminDefsRepoBlobRef(value)
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
        case "com.atproto.admin.defs#repoBlobRef":
            let value = try ComAtprotoAdminDefs.RepoBlobRef(from: decoder)
            self = .comAtprotoAdminDefsRepoBlobRef(value)
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
        case .comAtprotoAdminDefsRepoBlobRef(let value):
            try container.encode("com.atproto.admin.defs#repoBlobRef", forKey: .type)
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
        case .comAtprotoAdminDefsRepoBlobRef(let value):
            hasher.combine("com.atproto.admin.defs#repoBlobRef")
            hasher.combine(value)
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: OutputSubjectUnion, rhs: OutputSubjectUnion) -> Bool {
        switch (lhs, rhs) {
        case (.comAtprotoAdminDefsRepoRef(let lhsValue),
              .comAtprotoAdminDefsRepoRef(let rhsValue)):
            return lhsValue == rhsValue
        case (.comAtprotoRepoStrongRef(let lhsValue),
              .comAtprotoRepoStrongRef(let rhsValue)):
            return lhsValue == rhsValue
        case (.comAtprotoAdminDefsRepoBlobRef(let lhsValue),
              .comAtprotoAdminDefsRepoBlobRef(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? OutputSubjectUnion else { return false }
        return self == other
    }
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        // Create an ordered map to maintain field order
        var map = OrderedCBORMap()
        
        switch self {
        case .comAtprotoAdminDefsRepoRef(let value):
            map = map.adding(key: "$type", value: "com.atproto.admin.defs#repoRef")
            
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
        case .comAtprotoRepoStrongRef(let value):
            map = map.adding(key: "$type", value: "com.atproto.repo.strongRef")
            
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
        case .comAtprotoAdminDefsRepoBlobRef(let value):
            map = map.adding(key: "$type", value: "com.atproto.admin.defs#repoBlobRef")
            
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
    
    /// Property that indicates if this enum contains pending data that needs loading
    public var hasPendingData: Bool {
        switch self {
        
        case .comAtprotoAdminDefsRepoRef(let value):
            return value.hasPendingData
        case .comAtprotoRepoStrongRef(let value):
            return value.hasPendingData
        case .comAtprotoAdminDefsRepoBlobRef(let value):
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
        case .comAtprotoAdminDefsRepoBlobRef(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .comAtprotoAdminDefsRepoBlobRef(value)
        case .unexpected:
            // Nothing to load for unexpected values
            break
        }
    }
}




public enum ComAtprotoAdminUpdateSubjectStatusSubjectUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
    case comAtprotoAdminDefsRepoRef(ComAtprotoAdminDefs.RepoRef)
    case comAtprotoRepoStrongRef(ComAtprotoRepoStrongRef)
    case comAtprotoAdminDefsRepoBlobRef(ComAtprotoAdminDefs.RepoBlobRef)
    case unexpected(ATProtocolValueContainer)
    
    public init(_ value: ComAtprotoAdminDefs.RepoRef) {
        self = .comAtprotoAdminDefsRepoRef(value)
    }
    public init(_ value: ComAtprotoRepoStrongRef) {
        self = .comAtprotoRepoStrongRef(value)
    }
    public init(_ value: ComAtprotoAdminDefs.RepoBlobRef) {
        self = .comAtprotoAdminDefsRepoBlobRef(value)
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
        case "com.atproto.admin.defs#repoBlobRef":
            let value = try ComAtprotoAdminDefs.RepoBlobRef(from: decoder)
            self = .comAtprotoAdminDefsRepoBlobRef(value)
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
        case .comAtprotoAdminDefsRepoBlobRef(let value):
            try container.encode("com.atproto.admin.defs#repoBlobRef", forKey: .type)
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
        case .comAtprotoAdminDefsRepoBlobRef(let value):
            hasher.combine("com.atproto.admin.defs#repoBlobRef")
            hasher.combine(value)
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: ComAtprotoAdminUpdateSubjectStatusSubjectUnion, rhs: ComAtprotoAdminUpdateSubjectStatusSubjectUnion) -> Bool {
        switch (lhs, rhs) {
        case (.comAtprotoAdminDefsRepoRef(let lhsValue),
              .comAtprotoAdminDefsRepoRef(let rhsValue)):
            return lhsValue == rhsValue
        case (.comAtprotoRepoStrongRef(let lhsValue),
              .comAtprotoRepoStrongRef(let rhsValue)):
            return lhsValue == rhsValue
        case (.comAtprotoAdminDefsRepoBlobRef(let lhsValue),
              .comAtprotoAdminDefsRepoBlobRef(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? ComAtprotoAdminUpdateSubjectStatusSubjectUnion else { return false }
        return self == other
    }
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        // Create an ordered map to maintain field order
        var map = OrderedCBORMap()
        
        switch self {
        case .comAtprotoAdminDefsRepoRef(let value):
            map = map.adding(key: "$type", value: "com.atproto.admin.defs#repoRef")
            
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
        case .comAtprotoRepoStrongRef(let value):
            map = map.adding(key: "$type", value: "com.atproto.repo.strongRef")
            
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
        case .comAtprotoAdminDefsRepoBlobRef(let value):
            map = map.adding(key: "$type", value: "com.atproto.admin.defs#repoBlobRef")
            
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
    
    /// Property that indicates if this enum contains pending data that needs loading
    public var hasPendingData: Bool {
        switch self {
        
        case .comAtprotoAdminDefsRepoRef(let value):
            return value.hasPendingData
        case .comAtprotoRepoStrongRef(let value):
            return value.hasPendingData
        case .comAtprotoAdminDefsRepoBlobRef(let value):
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
        case .comAtprotoAdminDefsRepoBlobRef(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .comAtprotoAdminDefsRepoBlobRef(value)
        case .unexpected:
            // Nothing to load for unexpected values
            break
        }
    }
}


}

extension ATProtoClient.Com.Atproto.Admin {
    // MARK: - updateSubjectStatus

    /// Update the service-specific admin status of a subject (account, record, or blob).
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func updateSubjectStatus(
        
        input: ComAtprotoAdminUpdateSubjectStatus.Input
        
    ) async throws -> (responseCode: Int, data: ComAtprotoAdminUpdateSubjectStatus.Output?) {
        let endpoint = "com.atproto.admin.updateSubjectStatus"
        
        var headers: [String: String] = [:]
        
        headers["Content-Type"] = "application/json"
        
        
        
        headers["Accept"] = "application/json"
        

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        
        let (responseData, response) = try await networkService.performRequest(urlRequest)
        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        
        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(ComAtprotoAdminUpdateSubjectStatus.Output.self, from: responseData)
        

        return (responseCode, decodedData)
        
    }
    
}
                           
