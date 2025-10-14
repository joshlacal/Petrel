import Foundation



// lexicon: 1, id: com.atproto.repo.applyWrites


public struct ComAtprotoRepoApplyWrites { 

    public static let typeIdentifier = "com.atproto.repo.applyWrites"
        
public struct Create: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "com.atproto.repo.applyWrites#create"
            public let collection: NSID
            public let rkey: RecordKey?
            public let value: ATProtocolValueContainer

        // Standard initializer
        public init(
            collection: NSID, rkey: RecordKey?, value: ATProtocolValueContainer
        ) {
            
            self.collection = collection
            self.rkey = rkey
            self.value = value
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.collection = try container.decode(NSID.self, forKey: .collection)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'collection': \(error)")
                
                throw error
            }
            do {
                
                
                self.rkey = try container.decodeIfPresent(RecordKey.self, forKey: .rkey)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'rkey': \(error)")
                
                throw error
            }
            do {
                
                
                self.value = try container.decode(ATProtocolValueContainer.self, forKey: .value)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'value': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(collection, forKey: .collection)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(rkey, forKey: .rkey)
            
            
            
            
            try container.encode(value, forKey: .value)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(collection)
            if let value = rkey {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(value)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.collection != other.collection {
                return false
            }
            
            
            
            
            if rkey != other.rkey {
                return false
            }
            
            
            
            
            if self.value != other.value {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let collectionValue = try collection.toCBORValue()
            map = map.adding(key: "collection", value: collectionValue)
            
            
            
            
            
            if let value = rkey {
                // Encode optional property even if it's an empty array for CBOR
                
                let rkeyValue = try value.toCBORValue()
                map = map.adding(key: "rkey", value: rkeyValue)
            }
            
            
            
            
            
            
            let valueValue = try value.toCBORValue()
            map = map.adding(key: "value", value: valueValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case collection
            case rkey
            case value
        }
    }
        
public struct Update: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "com.atproto.repo.applyWrites#update"
            public let collection: NSID
            public let rkey: RecordKey
            public let value: ATProtocolValueContainer

        // Standard initializer
        public init(
            collection: NSID, rkey: RecordKey, value: ATProtocolValueContainer
        ) {
            
            self.collection = collection
            self.rkey = rkey
            self.value = value
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.collection = try container.decode(NSID.self, forKey: .collection)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'collection': \(error)")
                
                throw error
            }
            do {
                
                
                self.rkey = try container.decode(RecordKey.self, forKey: .rkey)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'rkey': \(error)")
                
                throw error
            }
            do {
                
                
                self.value = try container.decode(ATProtocolValueContainer.self, forKey: .value)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'value': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(collection, forKey: .collection)
            
            
            
            
            try container.encode(rkey, forKey: .rkey)
            
            
            
            
            try container.encode(value, forKey: .value)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(collection)
            hasher.combine(rkey)
            hasher.combine(value)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.collection != other.collection {
                return false
            }
            
            
            
            
            if self.rkey != other.rkey {
                return false
            }
            
            
            
            
            if self.value != other.value {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let collectionValue = try collection.toCBORValue()
            map = map.adding(key: "collection", value: collectionValue)
            
            
            
            
            
            
            let rkeyValue = try rkey.toCBORValue()
            map = map.adding(key: "rkey", value: rkeyValue)
            
            
            
            
            
            
            let valueValue = try value.toCBORValue()
            map = map.adding(key: "value", value: valueValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case collection
            case rkey
            case value
        }
    }
        
public struct Delete: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "com.atproto.repo.applyWrites#delete"
            public let collection: NSID
            public let rkey: RecordKey

        // Standard initializer
        public init(
            collection: NSID, rkey: RecordKey
        ) {
            
            self.collection = collection
            self.rkey = rkey
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.collection = try container.decode(NSID.self, forKey: .collection)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'collection': \(error)")
                
                throw error
            }
            do {
                
                
                self.rkey = try container.decode(RecordKey.self, forKey: .rkey)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'rkey': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(collection, forKey: .collection)
            
            
            
            
            try container.encode(rkey, forKey: .rkey)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(collection)
            hasher.combine(rkey)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.collection != other.collection {
                return false
            }
            
            
            
            
            if self.rkey != other.rkey {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let collectionValue = try collection.toCBORValue()
            map = map.adding(key: "collection", value: collectionValue)
            
            
            
            
            
            
            let rkeyValue = try rkey.toCBORValue()
            map = map.adding(key: "rkey", value: rkeyValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case collection
            case rkey
        }
    }
        
public struct CreateResult: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "com.atproto.repo.applyWrites#createResult"
            public let uri: ATProtocolURI
            public let cid: CID
            public let validationStatus: String?

        // Standard initializer
        public init(
            uri: ATProtocolURI, cid: CID, validationStatus: String?
        ) {
            
            self.uri = uri
            self.cid = cid
            self.validationStatus = validationStatus
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.uri = try container.decode(ATProtocolURI.self, forKey: .uri)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'uri': \(error)")
                
                throw error
            }
            do {
                
                
                self.cid = try container.decode(CID.self, forKey: .cid)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'cid': \(error)")
                
                throw error
            }
            do {
                
                
                self.validationStatus = try container.decodeIfPresent(String.self, forKey: .validationStatus)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'validationStatus': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(uri, forKey: .uri)
            
            
            
            
            try container.encode(cid, forKey: .cid)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(validationStatus, forKey: .validationStatus)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
            hasher.combine(cid)
            if let value = validationStatus {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.uri != other.uri {
                return false
            }
            
            
            
            
            if self.cid != other.cid {
                return false
            }
            
            
            
            
            if validationStatus != other.validationStatus {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let uriValue = try uri.toCBORValue()
            map = map.adding(key: "uri", value: uriValue)
            
            
            
            
            
            
            let cidValue = try cid.toCBORValue()
            map = map.adding(key: "cid", value: cidValue)
            
            
            
            
            
            if let value = validationStatus {
                // Encode optional property even if it's an empty array for CBOR
                
                let validationStatusValue = try value.toCBORValue()
                map = map.adding(key: "validationStatus", value: validationStatusValue)
            }
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
            case cid
            case validationStatus
        }
    }
        
public struct UpdateResult: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "com.atproto.repo.applyWrites#updateResult"
            public let uri: ATProtocolURI
            public let cid: CID
            public let validationStatus: String?

        // Standard initializer
        public init(
            uri: ATProtocolURI, cid: CID, validationStatus: String?
        ) {
            
            self.uri = uri
            self.cid = cid
            self.validationStatus = validationStatus
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.uri = try container.decode(ATProtocolURI.self, forKey: .uri)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'uri': \(error)")
                
                throw error
            }
            do {
                
                
                self.cid = try container.decode(CID.self, forKey: .cid)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'cid': \(error)")
                
                throw error
            }
            do {
                
                
                self.validationStatus = try container.decodeIfPresent(String.self, forKey: .validationStatus)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'validationStatus': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(uri, forKey: .uri)
            
            
            
            
            try container.encode(cid, forKey: .cid)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(validationStatus, forKey: .validationStatus)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
            hasher.combine(cid)
            if let value = validationStatus {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.uri != other.uri {
                return false
            }
            
            
            
            
            if self.cid != other.cid {
                return false
            }
            
            
            
            
            if validationStatus != other.validationStatus {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let uriValue = try uri.toCBORValue()
            map = map.adding(key: "uri", value: uriValue)
            
            
            
            
            
            
            let cidValue = try cid.toCBORValue()
            map = map.adding(key: "cid", value: cidValue)
            
            
            
            
            
            if let value = validationStatus {
                // Encode optional property even if it's an empty array for CBOR
                
                let validationStatusValue = try value.toCBORValue()
                map = map.adding(key: "validationStatus", value: validationStatusValue)
            }
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
            case cid
            case validationStatus
        }
    }
        
public struct DeleteResult: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "com.atproto.repo.applyWrites#deleteResult"

        // Standard initializer
        public init(
            
        ) {
            
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let _ = decoder  // Acknowledge parameter for empty struct
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
        }

        public func hash(into hasher: inout Hasher) {
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            return other is Self  // For empty structs, just check the type
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
        }
    }
public struct Input: ATProtocolCodable {
            public let repo: ATIdentifier
            public let validate: Bool?
            public let writes: [InputWritesUnion]
            public let swapCommit: CID?

            // Standard public initializer
            public init(repo: ATIdentifier, validate: Bool? = nil, writes: [InputWritesUnion], swapCommit: CID? = nil) {
                self.repo = repo
                self.validate = validate
                self.writes = writes
                self.swapCommit = swapCommit
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.repo = try container.decode(ATIdentifier.self, forKey: .repo)
                
                
                self.validate = try container.decodeIfPresent(Bool.self, forKey: .validate)
                
                
                self.writes = try container.decode([InputWritesUnion].self, forKey: .writes)
                
                
                self.swapCommit = try container.decodeIfPresent(CID.self, forKey: .swapCommit)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(repo, forKey: .repo)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(validate, forKey: .validate)
                
                
                try container.encode(writes, forKey: .writes)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(swapCommit, forKey: .swapCommit)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case repo
                case validate
                case writes
                case swapCommit
            }
            
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()

                
                
                let repoValue = try repo.toCBORValue()
                map = map.adding(key: "repo", value: repoValue)
                
                
                
                if let value = validate {
                    // Encode optional property even if it's an empty array for CBOR
                    let validateValue = try value.toCBORValue()
                    map = map.adding(key: "validate", value: validateValue)
                }
                
                
                
                let writesValue = try writes.toCBORValue()
                map = map.adding(key: "writes", value: writesValue)
                
                
                
                if let value = swapCommit {
                    // Encode optional property even if it's an empty array for CBOR
                    let swapCommitValue = try value.toCBORValue()
                    map = map.adding(key: "swapCommit", value: swapCommitValue)
                }
                
                

                return map
            }
        }
    
public struct Output: ATProtocolCodable {
        
        
        public let commit: ComAtprotoRepoDefs.CommitMeta?
        
        public let results: [OutputResultsUnion]?
        
        
        
        // Standard public initializer
        public init(
            
            
            commit: ComAtprotoRepoDefs.CommitMeta? = nil,
            
            results: [OutputResultsUnion]? = nil
            
            
        ) {
            
            
            self.commit = commit
            
            self.results = results
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.commit = try container.decodeIfPresent(ComAtprotoRepoDefs.CommitMeta.self, forKey: .commit)
            
            
            self.results = try container.decodeIfPresent([OutputResultsUnion].self, forKey: .results)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(commit, forKey: .commit)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(results, forKey: .results)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            if let value = commit {
                // Encode optional property even if it's an empty array for CBOR
                let commitValue = try value.toCBORValue()
                map = map.adding(key: "commit", value: commitValue)
            }
            
            
            
            if let value = results {
                // Encode optional property even if it's an empty array for CBOR
                let resultsValue = try value.toCBORValue()
                map = map.adding(key: "results", value: resultsValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case commit
            case results
        }
        
    }
        
public enum Error: String, Swift.Error, CustomStringConvertible {
                case invalidSwap = "InvalidSwap.Indicates that the 'swapCommit' parameter did not match current commit."
            public var description: String {
                return self.rawValue
            }
        }





public enum InputWritesUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
    case comAtprotoRepoApplyWritesCreate(ComAtprotoRepoApplyWrites.Create)
    case comAtprotoRepoApplyWritesUpdate(ComAtprotoRepoApplyWrites.Update)
    case comAtprotoRepoApplyWritesDelete(ComAtprotoRepoApplyWrites.Delete)
    case unexpected(ATProtocolValueContainer)
    
    public init(_ value: ComAtprotoRepoApplyWrites.Create) {
        self = .comAtprotoRepoApplyWritesCreate(value)
    }
    public init(_ value: ComAtprotoRepoApplyWrites.Update) {
        self = .comAtprotoRepoApplyWritesUpdate(value)
    }
    public init(_ value: ComAtprotoRepoApplyWrites.Delete) {
        self = .comAtprotoRepoApplyWritesDelete(value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)
        

        switch typeValue {
        case "com.atproto.repo.applyWrites#create":
            let value = try ComAtprotoRepoApplyWrites.Create(from: decoder)
            self = .comAtprotoRepoApplyWritesCreate(value)
        case "com.atproto.repo.applyWrites#update":
            let value = try ComAtprotoRepoApplyWrites.Update(from: decoder)
            self = .comAtprotoRepoApplyWritesUpdate(value)
        case "com.atproto.repo.applyWrites#delete":
            let value = try ComAtprotoRepoApplyWrites.Delete(from: decoder)
            self = .comAtprotoRepoApplyWritesDelete(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .comAtprotoRepoApplyWritesCreate(let value):
            try container.encode("com.atproto.repo.applyWrites#create", forKey: .type)
            try value.encode(to: encoder)
        case .comAtprotoRepoApplyWritesUpdate(let value):
            try container.encode("com.atproto.repo.applyWrites#update", forKey: .type)
            try value.encode(to: encoder)
        case .comAtprotoRepoApplyWritesDelete(let value):
            try container.encode("com.atproto.repo.applyWrites#delete", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let container):
            try container.encode(to: encoder)
        
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .comAtprotoRepoApplyWritesCreate(let value):
            hasher.combine("com.atproto.repo.applyWrites#create")
            hasher.combine(value)
        case .comAtprotoRepoApplyWritesUpdate(let value):
            hasher.combine("com.atproto.repo.applyWrites#update")
            hasher.combine(value)
        case .comAtprotoRepoApplyWritesDelete(let value):
            hasher.combine("com.atproto.repo.applyWrites#delete")
            hasher.combine(value)
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: InputWritesUnion, rhs: InputWritesUnion) -> Bool {
        switch (lhs, rhs) {
        case (.comAtprotoRepoApplyWritesCreate(let lhsValue),
              .comAtprotoRepoApplyWritesCreate(let rhsValue)):
            return lhsValue == rhsValue
        case (.comAtprotoRepoApplyWritesUpdate(let lhsValue),
              .comAtprotoRepoApplyWritesUpdate(let rhsValue)):
            return lhsValue == rhsValue
        case (.comAtprotoRepoApplyWritesDelete(let lhsValue),
              .comAtprotoRepoApplyWritesDelete(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? InputWritesUnion else { return false }
        return self == other
    }
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        // Create an ordered map to maintain field order
        var map = OrderedCBORMap()
        
        switch self {
        case .comAtprotoRepoApplyWritesCreate(let value):
            map = map.adding(key: "$type", value: "com.atproto.repo.applyWrites#create")
            
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
        case .comAtprotoRepoApplyWritesUpdate(let value):
            map = map.adding(key: "$type", value: "com.atproto.repo.applyWrites#update")
            
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
        case .comAtprotoRepoApplyWritesDelete(let value):
            map = map.adding(key: "$type", value: "com.atproto.repo.applyWrites#delete")
            
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
        
        case .comAtprotoRepoApplyWritesCreate(let value):
            return value.hasPendingData
        case .comAtprotoRepoApplyWritesUpdate(let value):
            return value.hasPendingData
        case .comAtprotoRepoApplyWritesDelete(let value):
            return value.hasPendingData
        case .unexpected:
            return false
        }
    }
    
    /// Attempts to load any pending data in this enum or its children
    public mutating func loadPendingData() async {
        switch self {
        
        case .comAtprotoRepoApplyWritesCreate(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .comAtprotoRepoApplyWritesCreate(value)
        case .comAtprotoRepoApplyWritesUpdate(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .comAtprotoRepoApplyWritesUpdate(value)
        case .comAtprotoRepoApplyWritesDelete(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .comAtprotoRepoApplyWritesDelete(value)
        case .unexpected:
            // Nothing to load for unexpected values
            break
        }
    }
}




public enum OutputResultsUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
    case comAtprotoRepoApplyWritesCreateResult(ComAtprotoRepoApplyWrites.CreateResult)
    case comAtprotoRepoApplyWritesUpdateResult(ComAtprotoRepoApplyWrites.UpdateResult)
    case comAtprotoRepoApplyWritesDeleteResult(ComAtprotoRepoApplyWrites.DeleteResult)
    case unexpected(ATProtocolValueContainer)
    
    public init(_ value: ComAtprotoRepoApplyWrites.CreateResult) {
        self = .comAtprotoRepoApplyWritesCreateResult(value)
    }
    public init(_ value: ComAtprotoRepoApplyWrites.UpdateResult) {
        self = .comAtprotoRepoApplyWritesUpdateResult(value)
    }
    public init(_ value: ComAtprotoRepoApplyWrites.DeleteResult) {
        self = .comAtprotoRepoApplyWritesDeleteResult(value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)
        

        switch typeValue {
        case "com.atproto.repo.applyWrites#createResult":
            let value = try ComAtprotoRepoApplyWrites.CreateResult(from: decoder)
            self = .comAtprotoRepoApplyWritesCreateResult(value)
        case "com.atproto.repo.applyWrites#updateResult":
            let value = try ComAtprotoRepoApplyWrites.UpdateResult(from: decoder)
            self = .comAtprotoRepoApplyWritesUpdateResult(value)
        case "com.atproto.repo.applyWrites#deleteResult":
            let value = try ComAtprotoRepoApplyWrites.DeleteResult(from: decoder)
            self = .comAtprotoRepoApplyWritesDeleteResult(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .comAtprotoRepoApplyWritesCreateResult(let value):
            try container.encode("com.atproto.repo.applyWrites#createResult", forKey: .type)
            try value.encode(to: encoder)
        case .comAtprotoRepoApplyWritesUpdateResult(let value):
            try container.encode("com.atproto.repo.applyWrites#updateResult", forKey: .type)
            try value.encode(to: encoder)
        case .comAtprotoRepoApplyWritesDeleteResult(let value):
            try container.encode("com.atproto.repo.applyWrites#deleteResult", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let container):
            try container.encode(to: encoder)
        
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .comAtprotoRepoApplyWritesCreateResult(let value):
            hasher.combine("com.atproto.repo.applyWrites#createResult")
            hasher.combine(value)
        case .comAtprotoRepoApplyWritesUpdateResult(let value):
            hasher.combine("com.atproto.repo.applyWrites#updateResult")
            hasher.combine(value)
        case .comAtprotoRepoApplyWritesDeleteResult(let value):
            hasher.combine("com.atproto.repo.applyWrites#deleteResult")
            hasher.combine(value)
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: OutputResultsUnion, rhs: OutputResultsUnion) -> Bool {
        switch (lhs, rhs) {
        case (.comAtprotoRepoApplyWritesCreateResult(let lhsValue),
              .comAtprotoRepoApplyWritesCreateResult(let rhsValue)):
            return lhsValue == rhsValue
        case (.comAtprotoRepoApplyWritesUpdateResult(let lhsValue),
              .comAtprotoRepoApplyWritesUpdateResult(let rhsValue)):
            return lhsValue == rhsValue
        case (.comAtprotoRepoApplyWritesDeleteResult(let lhsValue),
              .comAtprotoRepoApplyWritesDeleteResult(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? OutputResultsUnion else { return false }
        return self == other
    }
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        // Create an ordered map to maintain field order
        var map = OrderedCBORMap()
        
        switch self {
        case .comAtprotoRepoApplyWritesCreateResult(let value):
            map = map.adding(key: "$type", value: "com.atproto.repo.applyWrites#createResult")
            
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
        case .comAtprotoRepoApplyWritesUpdateResult(let value):
            map = map.adding(key: "$type", value: "com.atproto.repo.applyWrites#updateResult")
            
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
        case .comAtprotoRepoApplyWritesDeleteResult(let value):
            map = map.adding(key: "$type", value: "com.atproto.repo.applyWrites#deleteResult")
            
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
        
        case .comAtprotoRepoApplyWritesCreateResult(let value):
            return value.hasPendingData
        case .comAtprotoRepoApplyWritesUpdateResult(let value):
            return value.hasPendingData
        case .comAtprotoRepoApplyWritesDeleteResult(let value):
            return value.hasPendingData
        case .unexpected:
            return false
        }
    }
    
    /// Attempts to load any pending data in this enum or its children
    public mutating func loadPendingData() async {
        switch self {
        
        case .comAtprotoRepoApplyWritesCreateResult(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .comAtprotoRepoApplyWritesCreateResult(value)
        case .comAtprotoRepoApplyWritesUpdateResult(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .comAtprotoRepoApplyWritesUpdateResult(value)
        case .comAtprotoRepoApplyWritesDeleteResult(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .comAtprotoRepoApplyWritesDeleteResult(value)
        case .unexpected:
            // Nothing to load for unexpected values
            break
        }
    }
}




public enum ComAtprotoRepoApplyWritesWritesUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
    case comAtprotoRepoApplyWritesCreate(ComAtprotoRepoApplyWrites.Create)
    case comAtprotoRepoApplyWritesUpdate(ComAtprotoRepoApplyWrites.Update)
    case comAtprotoRepoApplyWritesDelete(ComAtprotoRepoApplyWrites.Delete)
    case unexpected(ATProtocolValueContainer)
    
    public init(_ value: ComAtprotoRepoApplyWrites.Create) {
        self = .comAtprotoRepoApplyWritesCreate(value)
    }
    public init(_ value: ComAtprotoRepoApplyWrites.Update) {
        self = .comAtprotoRepoApplyWritesUpdate(value)
    }
    public init(_ value: ComAtprotoRepoApplyWrites.Delete) {
        self = .comAtprotoRepoApplyWritesDelete(value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)
        

        switch typeValue {
        case "com.atproto.repo.applyWrites#create":
            let value = try ComAtprotoRepoApplyWrites.Create(from: decoder)
            self = .comAtprotoRepoApplyWritesCreate(value)
        case "com.atproto.repo.applyWrites#update":
            let value = try ComAtprotoRepoApplyWrites.Update(from: decoder)
            self = .comAtprotoRepoApplyWritesUpdate(value)
        case "com.atproto.repo.applyWrites#delete":
            let value = try ComAtprotoRepoApplyWrites.Delete(from: decoder)
            self = .comAtprotoRepoApplyWritesDelete(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .comAtprotoRepoApplyWritesCreate(let value):
            try container.encode("com.atproto.repo.applyWrites#create", forKey: .type)
            try value.encode(to: encoder)
        case .comAtprotoRepoApplyWritesUpdate(let value):
            try container.encode("com.atproto.repo.applyWrites#update", forKey: .type)
            try value.encode(to: encoder)
        case .comAtprotoRepoApplyWritesDelete(let value):
            try container.encode("com.atproto.repo.applyWrites#delete", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let container):
            try container.encode(to: encoder)
        
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .comAtprotoRepoApplyWritesCreate(let value):
            hasher.combine("com.atproto.repo.applyWrites#create")
            hasher.combine(value)
        case .comAtprotoRepoApplyWritesUpdate(let value):
            hasher.combine("com.atproto.repo.applyWrites#update")
            hasher.combine(value)
        case .comAtprotoRepoApplyWritesDelete(let value):
            hasher.combine("com.atproto.repo.applyWrites#delete")
            hasher.combine(value)
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: ComAtprotoRepoApplyWritesWritesUnion, rhs: ComAtprotoRepoApplyWritesWritesUnion) -> Bool {
        switch (lhs, rhs) {
        case (.comAtprotoRepoApplyWritesCreate(let lhsValue),
              .comAtprotoRepoApplyWritesCreate(let rhsValue)):
            return lhsValue == rhsValue
        case (.comAtprotoRepoApplyWritesUpdate(let lhsValue),
              .comAtprotoRepoApplyWritesUpdate(let rhsValue)):
            return lhsValue == rhsValue
        case (.comAtprotoRepoApplyWritesDelete(let lhsValue),
              .comAtprotoRepoApplyWritesDelete(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? ComAtprotoRepoApplyWritesWritesUnion else { return false }
        return self == other
    }
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        // Create an ordered map to maintain field order
        var map = OrderedCBORMap()
        
        switch self {
        case .comAtprotoRepoApplyWritesCreate(let value):
            map = map.adding(key: "$type", value: "com.atproto.repo.applyWrites#create")
            
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
        case .comAtprotoRepoApplyWritesUpdate(let value):
            map = map.adding(key: "$type", value: "com.atproto.repo.applyWrites#update")
            
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
        case .comAtprotoRepoApplyWritesDelete(let value):
            map = map.adding(key: "$type", value: "com.atproto.repo.applyWrites#delete")
            
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
        
        case .comAtprotoRepoApplyWritesCreate(let value):
            return value.hasPendingData
        case .comAtprotoRepoApplyWritesUpdate(let value):
            return value.hasPendingData
        case .comAtprotoRepoApplyWritesDelete(let value):
            return value.hasPendingData
        case .unexpected:
            return false
        }
    }
    
    /// Attempts to load any pending data in this enum or its children
    public mutating func loadPendingData() async {
        switch self {
        
        case .comAtprotoRepoApplyWritesCreate(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .comAtprotoRepoApplyWritesCreate(value)
        case .comAtprotoRepoApplyWritesUpdate(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .comAtprotoRepoApplyWritesUpdate(value)
        case .comAtprotoRepoApplyWritesDelete(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .comAtprotoRepoApplyWritesDelete(value)
        case .unexpected:
            // Nothing to load for unexpected values
            break
        }
    }
}


}

extension ATProtoClient.Com.Atproto.Repo {
    // MARK: - applyWrites

    /// Apply a batch transaction of repository creates, updates, and deletes. Requires auth, implemented by PDS.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func applyWrites(
        
        input: ComAtprotoRepoApplyWrites.Input
        
    ) async throws -> (responseCode: Int, data: ComAtprotoRepoApplyWrites.Output?) {
        let endpoint = "com.atproto.repo.applyWrites"
        
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

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "com.atproto.repo.applyWrites")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        
        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        // Only decode response data if request was successful
        if (200...299).contains(responseCode) {
            do {
                
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(ComAtprotoRepoApplyWrites.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for com.atproto.repo.applyWrites: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           
