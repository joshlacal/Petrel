import Foundation

// lexicon: 1, id: com.atproto.server.defs

public enum ComAtprotoServerDefs {
    public static let typeIdentifier = "com.atproto.server.defs"

    public struct InviteCode: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "com.atproto.server.defs#inviteCode"
        public let code: String
        public let available: Int
        public let disabled: Bool
        public let forAccount: String
        public let createdBy: String
        public let createdAt: ATProtocolDate
        public let uses: [InviteCodeUse]

        // Standard initializer
        public init(
            code: String, available: Int, disabled: Bool, forAccount: String, createdBy: String, createdAt: ATProtocolDate, uses: [InviteCodeUse]
        ) {
            self.code = code
            self.available = available
            self.disabled = disabled
            self.forAccount = forAccount
            self.createdBy = createdBy
            self.createdAt = createdAt
            self.uses = uses
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                code = try container.decode(String.self, forKey: .code)

            } catch {
                LogManager.logError("Decoding error for property 'code': \(error)")
                throw error
            }
            do {
                available = try container.decode(Int.self, forKey: .available)

            } catch {
                LogManager.logError("Decoding error for property 'available': \(error)")
                throw error
            }
            do {
                disabled = try container.decode(Bool.self, forKey: .disabled)

            } catch {
                LogManager.logError("Decoding error for property 'disabled': \(error)")
                throw error
            }
            do {
                forAccount = try container.decode(String.self, forKey: .forAccount)

            } catch {
                LogManager.logError("Decoding error for property 'forAccount': \(error)")
                throw error
            }
            do {
                createdBy = try container.decode(String.self, forKey: .createdBy)

            } catch {
                LogManager.logError("Decoding error for property 'createdBy': \(error)")
                throw error
            }
            do {
                createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)

            } catch {
                LogManager.logError("Decoding error for property 'createdAt': \(error)")
                throw error
            }
            do {
                uses = try container.decode([InviteCodeUse].self, forKey: .uses)

            } catch {
                LogManager.logError("Decoding error for property 'uses': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(code, forKey: .code)

            try container.encode(available, forKey: .available)

            try container.encode(disabled, forKey: .disabled)

            try container.encode(forAccount, forKey: .forAccount)

            try container.encode(createdBy, forKey: .createdBy)

            try container.encode(createdAt, forKey: .createdAt)

            try container.encode(uses, forKey: .uses)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(code)
            hasher.combine(available)
            hasher.combine(disabled)
            hasher.combine(forAccount)
            hasher.combine(createdBy)
            hasher.combine(createdAt)
            hasher.combine(uses)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if code != other.code {
                return false
            }

            if available != other.available {
                return false
            }

            if disabled != other.disabled {
                return false
            }

            if forAccount != other.forAccount {
                return false
            }

            if createdBy != other.createdBy {
                return false
            }

            if createdAt != other.createdAt {
                return false
            }

            if uses != other.uses {
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

            let codeValue = try (code as? DAGCBOREncodable)?.toCBORValue() ?? code
            map = map.adding(key: "code", value: codeValue)

            let availableValue = try (available as? DAGCBOREncodable)?.toCBORValue() ?? available
            map = map.adding(key: "available", value: availableValue)

            let disabledValue = try (disabled as? DAGCBOREncodable)?.toCBORValue() ?? disabled
            map = map.adding(key: "disabled", value: disabledValue)

            let forAccountValue = try (forAccount as? DAGCBOREncodable)?.toCBORValue() ?? forAccount
            map = map.adding(key: "forAccount", value: forAccountValue)

            let createdByValue = try (createdBy as? DAGCBOREncodable)?.toCBORValue() ?? createdBy
            map = map.adding(key: "createdBy", value: createdByValue)

            let createdAtValue = try (createdAt as? DAGCBOREncodable)?.toCBORValue() ?? createdAt
            map = map.adding(key: "createdAt", value: createdAtValue)

            let usesValue = try (uses as? DAGCBOREncodable)?.toCBORValue() ?? uses
            map = map.adding(key: "uses", value: usesValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case code
            case available
            case disabled
            case forAccount
            case createdBy
            case createdAt
            case uses
        }
    }

    public struct InviteCodeUse: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "com.atproto.server.defs#inviteCodeUse"
        public let usedBy: DID
        public let usedAt: ATProtocolDate

        // Standard initializer
        public init(
            usedBy: DID, usedAt: ATProtocolDate
        ) {
            self.usedBy = usedBy
            self.usedAt = usedAt
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                usedBy = try container.decode(DID.self, forKey: .usedBy)

            } catch {
                LogManager.logError("Decoding error for property 'usedBy': \(error)")
                throw error
            }
            do {
                usedAt = try container.decode(ATProtocolDate.self, forKey: .usedAt)

            } catch {
                LogManager.logError("Decoding error for property 'usedAt': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(usedBy, forKey: .usedBy)

            try container.encode(usedAt, forKey: .usedAt)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(usedBy)
            hasher.combine(usedAt)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if usedBy != other.usedBy {
                return false
            }

            if usedAt != other.usedAt {
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

            let usedByValue = try (usedBy as? DAGCBOREncodable)?.toCBORValue() ?? usedBy
            map = map.adding(key: "usedBy", value: usedByValue)

            let usedAtValue = try (usedAt as? DAGCBOREncodable)?.toCBORValue() ?? usedAt
            map = map.adding(key: "usedAt", value: usedAtValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case usedBy
            case usedAt
        }
    }
}
