import Foundation

// lexicon: 1, id: com.atproto.repo.applyWrites

public enum ComAtprotoRepoApplyWrites {
    public static let typeIdentifier = "com.atproto.repo.applyWrites"

    public struct Create: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "com.atproto.repo.applyWrites#create"
        public let collection: String
        public let rkey: String?
        public let value: ATProtocolValueContainer

        // Standard initializer
        public init(
            collection: String, rkey: String?, value: ATProtocolValueContainer
        ) {
            self.collection = collection
            self.rkey = rkey
            self.value = value
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                collection = try container.decode(String.self, forKey: .collection)

            } catch {
                LogManager.logError("Decoding error for property 'collection': \(error)")
                throw error
            }
            do {
                rkey = try container.decodeIfPresent(String.self, forKey: .rkey)

            } catch {
                LogManager.logError("Decoding error for property 'rkey': \(error)")
                throw error
            }
            do {
                value = try container.decode(ATProtocolValueContainer.self, forKey: .value)

            } catch {
                LogManager.logError("Decoding error for property 'value': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(collection, forKey: .collection)

            if let value = rkey {
                try container.encode(value, forKey: .rkey)
            }

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

            if collection != other.collection {
                return false
            }

            if rkey != other.rkey {
                return false
            }

            if value != other.value {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
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
        public let collection: String
        public let rkey: String
        public let value: ATProtocolValueContainer

        // Standard initializer
        public init(
            collection: String, rkey: String, value: ATProtocolValueContainer
        ) {
            self.collection = collection
            self.rkey = rkey
            self.value = value
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                collection = try container.decode(String.self, forKey: .collection)

            } catch {
                LogManager.logError("Decoding error for property 'collection': \(error)")
                throw error
            }
            do {
                rkey = try container.decode(String.self, forKey: .rkey)

            } catch {
                LogManager.logError("Decoding error for property 'rkey': \(error)")
                throw error
            }
            do {
                value = try container.decode(ATProtocolValueContainer.self, forKey: .value)

            } catch {
                LogManager.logError("Decoding error for property 'value': \(error)")
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

            if collection != other.collection {
                return false
            }

            if rkey != other.rkey {
                return false
            }

            if value != other.value {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
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
        public let collection: String
        public let rkey: String

        // Standard initializer
        public init(
            collection: String, rkey: String
        ) {
            self.collection = collection
            self.rkey = rkey
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                collection = try container.decode(String.self, forKey: .collection)

            } catch {
                LogManager.logError("Decoding error for property 'collection': \(error)")
                throw error
            }
            do {
                rkey = try container.decode(String.self, forKey: .rkey)

            } catch {
                LogManager.logError("Decoding error for property 'rkey': \(error)")
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

            if collection != other.collection {
                return false
            }

            if rkey != other.rkey {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
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
        public let cid: String
        public let validationStatus: String?

        // Standard initializer
        public init(
            uri: ATProtocolURI, cid: String, validationStatus: String?
        ) {
            self.uri = uri
            self.cid = cid
            self.validationStatus = validationStatus
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                uri = try container.decode(ATProtocolURI.self, forKey: .uri)

            } catch {
                LogManager.logError("Decoding error for property 'uri': \(error)")
                throw error
            }
            do {
                cid = try container.decode(String.self, forKey: .cid)

            } catch {
                LogManager.logError("Decoding error for property 'cid': \(error)")
                throw error
            }
            do {
                validationStatus = try container.decodeIfPresent(String.self, forKey: .validationStatus)

            } catch {
                LogManager.logError("Decoding error for property 'validationStatus': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(uri, forKey: .uri)

            try container.encode(cid, forKey: .cid)

            if let value = validationStatus {
                try container.encode(value, forKey: .validationStatus)
            }
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

            if uri != other.uri {
                return false
            }

            if cid != other.cid {
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
        public let cid: String
        public let validationStatus: String?

        // Standard initializer
        public init(
            uri: ATProtocolURI, cid: String, validationStatus: String?
        ) {
            self.uri = uri
            self.cid = cid
            self.validationStatus = validationStatus
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                uri = try container.decode(ATProtocolURI.self, forKey: .uri)

            } catch {
                LogManager.logError("Decoding error for property 'uri': \(error)")
                throw error
            }
            do {
                cid = try container.decode(String.self, forKey: .cid)

            } catch {
                LogManager.logError("Decoding error for property 'cid': \(error)")
                throw error
            }
            do {
                validationStatus = try container.decodeIfPresent(String.self, forKey: .validationStatus)

            } catch {
                LogManager.logError("Decoding error for property 'validationStatus': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(uri, forKey: .uri)

            try container.encode(cid, forKey: .cid)

            if let value = validationStatus {
                try container.encode(value, forKey: .validationStatus)
            }
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

            if uri != other.uri {
                return false
            }

            if cid != other.cid {
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
        ) {}

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let _ = decoder // Acknowledge parameter for empty struct
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
        }

        public func hash(into hasher: inout Hasher) {}

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            return other is Self // For empty structs, just check the type
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
        }
    }

    public struct Input: ATProtocolCodable {
        public let repo: String
        public let validate: Bool?
        public let writes: [InputWritesUnion]
        public let swapCommit: String?

        // Standard public initializer
        public init(repo: String, validate: Bool? = nil, writes: [InputWritesUnion], swapCommit: String? = nil) {
            self.repo = repo
            self.validate = validate
            self.writes = writes
            self.swapCommit = swapCommit
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
    }

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case invalidSwap = "InvalidSwap.Indicates that the 'swapCommit' parameter did not match current commit."
        public var description: String {
            return rawValue
        }
    }

    public enum InputWritesUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, PendingDataLoadable, Equatable {
        case comAtprotoRepoApplyWritesCreate(ComAtprotoRepoApplyWrites.Create)
        case comAtprotoRepoApplyWritesUpdate(ComAtprotoRepoApplyWrites.Update)
        case comAtprotoRepoApplyWritesDelete(ComAtprotoRepoApplyWrites.Delete)
        case unexpected(ATProtocolValueContainer)

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
            case let .comAtprotoRepoApplyWritesCreate(value):
                try container.encode("com.atproto.repo.applyWrites#create", forKey: .type)
                try value.encode(to: encoder)
            case let .comAtprotoRepoApplyWritesUpdate(value):
                try container.encode("com.atproto.repo.applyWrites#update", forKey: .type)
                try value.encode(to: encoder)
            case let .comAtprotoRepoApplyWritesDelete(value):
                try container.encode("com.atproto.repo.applyWrites#delete", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .comAtprotoRepoApplyWritesCreate(value):
                hasher.combine("com.atproto.repo.applyWrites#create")
                hasher.combine(value)
            case let .comAtprotoRepoApplyWritesUpdate(value):
                hasher.combine("com.atproto.repo.applyWrites#update")
                hasher.combine(value)
            case let .comAtprotoRepoApplyWritesDelete(value):
                hasher.combine("com.atproto.repo.applyWrites#delete")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: InputWritesUnion, rhs: InputWritesUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .comAtprotoRepoApplyWritesCreate(lhsValue),
                .comAtprotoRepoApplyWritesCreate(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .comAtprotoRepoApplyWritesUpdate(lhsValue),
                .comAtprotoRepoApplyWritesUpdate(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .comAtprotoRepoApplyWritesDelete(lhsValue),
                .comAtprotoRepoApplyWritesDelete(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard other is InputWritesUnion else { return false }
            return self == (other as! InputWritesUnion)
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .comAtprotoRepoApplyWritesCreate(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .comAtprotoRepoApplyWritesUpdate(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .comAtprotoRepoApplyWritesDelete(value):
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
            case let .comAtprotoRepoApplyWritesCreate(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ComAtprotoRepoApplyWrites.Create.self, from: jsonData)
                    {
                        self = .comAtprotoRepoApplyWritesCreate(decodedValue)
                    }
                }
            case let .comAtprotoRepoApplyWritesUpdate(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ComAtprotoRepoApplyWrites.Update.self, from: jsonData)
                    {
                        self = .comAtprotoRepoApplyWritesUpdate(decodedValue)
                    }
                }
            case let .comAtprotoRepoApplyWritesDelete(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ComAtprotoRepoApplyWrites.Delete.self, from: jsonData)
                    {
                        self = .comAtprotoRepoApplyWritesDelete(decodedValue)
                    }
                }
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }

    public enum OutputResultsUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, PendingDataLoadable, Equatable {
        case comAtprotoRepoApplyWritesCreateResult(ComAtprotoRepoApplyWrites.CreateResult)
        case comAtprotoRepoApplyWritesUpdateResult(ComAtprotoRepoApplyWrites.UpdateResult)
        case comAtprotoRepoApplyWritesDeleteResult(ComAtprotoRepoApplyWrites.DeleteResult)
        case unexpected(ATProtocolValueContainer)

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
            case let .comAtprotoRepoApplyWritesCreateResult(value):
                try container.encode("com.atproto.repo.applyWrites#createResult", forKey: .type)
                try value.encode(to: encoder)
            case let .comAtprotoRepoApplyWritesUpdateResult(value):
                try container.encode("com.atproto.repo.applyWrites#updateResult", forKey: .type)
                try value.encode(to: encoder)
            case let .comAtprotoRepoApplyWritesDeleteResult(value):
                try container.encode("com.atproto.repo.applyWrites#deleteResult", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .comAtprotoRepoApplyWritesCreateResult(value):
                hasher.combine("com.atproto.repo.applyWrites#createResult")
                hasher.combine(value)
            case let .comAtprotoRepoApplyWritesUpdateResult(value):
                hasher.combine("com.atproto.repo.applyWrites#updateResult")
                hasher.combine(value)
            case let .comAtprotoRepoApplyWritesDeleteResult(value):
                hasher.combine("com.atproto.repo.applyWrites#deleteResult")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: OutputResultsUnion, rhs: OutputResultsUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .comAtprotoRepoApplyWritesCreateResult(lhsValue),
                .comAtprotoRepoApplyWritesCreateResult(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .comAtprotoRepoApplyWritesUpdateResult(lhsValue),
                .comAtprotoRepoApplyWritesUpdateResult(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .comAtprotoRepoApplyWritesDeleteResult(lhsValue),
                .comAtprotoRepoApplyWritesDeleteResult(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard other is OutputResultsUnion else { return false }
            return self == (other as! OutputResultsUnion)
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .comAtprotoRepoApplyWritesCreateResult(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .comAtprotoRepoApplyWritesUpdateResult(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .comAtprotoRepoApplyWritesDeleteResult(value):
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
            case let .comAtprotoRepoApplyWritesCreateResult(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ComAtprotoRepoApplyWrites.CreateResult.self, from: jsonData)
                    {
                        self = .comAtprotoRepoApplyWritesCreateResult(decodedValue)
                    }
                }
            case let .comAtprotoRepoApplyWritesUpdateResult(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ComAtprotoRepoApplyWrites.UpdateResult.self, from: jsonData)
                    {
                        self = .comAtprotoRepoApplyWritesUpdateResult(decodedValue)
                    }
                }
            case let .comAtprotoRepoApplyWritesDeleteResult(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ComAtprotoRepoApplyWrites.DeleteResult.self, from: jsonData)
                    {
                        self = .comAtprotoRepoApplyWritesDeleteResult(decodedValue)
                    }
                }
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }

    public enum ComAtprotoRepoApplyWritesWritesUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, PendingDataLoadable, Equatable {
        case comAtprotoRepoApplyWritesCreate(ComAtprotoRepoApplyWrites.Create)
        case comAtprotoRepoApplyWritesUpdate(ComAtprotoRepoApplyWrites.Update)
        case comAtprotoRepoApplyWritesDelete(ComAtprotoRepoApplyWrites.Delete)
        case unexpected(ATProtocolValueContainer)

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
            case let .comAtprotoRepoApplyWritesCreate(value):
                try container.encode("com.atproto.repo.applyWrites#create", forKey: .type)
                try value.encode(to: encoder)
            case let .comAtprotoRepoApplyWritesUpdate(value):
                try container.encode("com.atproto.repo.applyWrites#update", forKey: .type)
                try value.encode(to: encoder)
            case let .comAtprotoRepoApplyWritesDelete(value):
                try container.encode("com.atproto.repo.applyWrites#delete", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .comAtprotoRepoApplyWritesCreate(value):
                hasher.combine("com.atproto.repo.applyWrites#create")
                hasher.combine(value)
            case let .comAtprotoRepoApplyWritesUpdate(value):
                hasher.combine("com.atproto.repo.applyWrites#update")
                hasher.combine(value)
            case let .comAtprotoRepoApplyWritesDelete(value):
                hasher.combine("com.atproto.repo.applyWrites#delete")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: ComAtprotoRepoApplyWritesWritesUnion, rhs: ComAtprotoRepoApplyWritesWritesUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .comAtprotoRepoApplyWritesCreate(lhsValue),
                .comAtprotoRepoApplyWritesCreate(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .comAtprotoRepoApplyWritesUpdate(lhsValue),
                .comAtprotoRepoApplyWritesUpdate(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .comAtprotoRepoApplyWritesDelete(lhsValue),
                .comAtprotoRepoApplyWritesDelete(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard other is ComAtprotoRepoApplyWritesWritesUnion else { return false }
            return self == (other as! ComAtprotoRepoApplyWritesWritesUnion)
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .comAtprotoRepoApplyWritesCreate(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .comAtprotoRepoApplyWritesUpdate(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .comAtprotoRepoApplyWritesDelete(value):
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
            case let .comAtprotoRepoApplyWritesCreate(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ComAtprotoRepoApplyWrites.Create.self, from: jsonData)
                    {
                        self = .comAtprotoRepoApplyWritesCreate(decodedValue)
                    }
                }
            case let .comAtprotoRepoApplyWritesUpdate(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ComAtprotoRepoApplyWrites.Update.self, from: jsonData)
                    {
                        self = .comAtprotoRepoApplyWritesUpdate(decodedValue)
                    }
                }
            case let .comAtprotoRepoApplyWritesDelete(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(ComAtprotoRepoApplyWrites.Delete.self, from: jsonData)
                    {
                        self = .comAtprotoRepoApplyWritesDelete(decodedValue)
                    }
                }
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }
}

public extension ATProtoClient.Com.Atproto.Repo {
    /// Apply a batch transaction of repository creates, updates, and deletes. Requires auth, implemented by PDS.
    func applyWrites(
        input: ComAtprotoRepoApplyWrites.Input

    ) async throws -> (responseCode: Int, data: ComAtprotoRepoApplyWrites.Output?) {
        let endpoint = "com.atproto.repo.applyWrites"

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
        let decodedData = try? decoder.decode(ComAtprotoRepoApplyWrites.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
