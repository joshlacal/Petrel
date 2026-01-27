import Foundation

// lexicon: 1, id: app.bsky.ageassurance.defs

public enum AppBskyAgeassuranceDefs {
    public static let typeIdentifier = "app.bsky.ageassurance.defs"

    public struct State: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.ageassurance.defs#state"
        public let lastInitiatedAt: ATProtocolDate?
        public let status: AppBskyAgeassuranceDefs.Status
        public let access: AppBskyAgeassuranceDefs.Access

        /// Standard initializer
        public init(
            lastInitiatedAt: ATProtocolDate?, status: AppBskyAgeassuranceDefs.Status, access: AppBskyAgeassuranceDefs.Access
        ) {
            self.lastInitiatedAt = lastInitiatedAt
            self.status = status
            self.access = access
        }

        /// Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                lastInitiatedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .lastInitiatedAt)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'lastInitiatedAt': \(error)")

                throw error
            }
            do {
                status = try container.decode(AppBskyAgeassuranceDefs.Status.self, forKey: .status)

            } catch {
                LogManager.logError("Decoding error for required property 'status': \(error)")

                throw error
            }
            do {
                access = try container.decode(AppBskyAgeassuranceDefs.Access.self, forKey: .access)

            } catch {
                LogManager.logError("Decoding error for required property 'access': \(error)")

                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(lastInitiatedAt, forKey: .lastInitiatedAt)

            try container.encode(status, forKey: .status)

            try container.encode(access, forKey: .access)
        }

        public func hash(into hasher: inout Hasher) {
            if let value = lastInitiatedAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(status)
            hasher.combine(access)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if lastInitiatedAt != other.lastInitiatedAt {
                return false
            }

            if status != other.status {
                return false
            }

            if access != other.access {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            if let value = lastInitiatedAt {
                // Encode optional property even if it's an empty array for CBOR

                let lastInitiatedAtValue = try value.toCBORValue()
                map = map.adding(key: "lastInitiatedAt", value: lastInitiatedAtValue)
            }

            let statusValue = try status.toCBORValue()
            map = map.adding(key: "status", value: statusValue)

            let accessValue = try access.toCBORValue()
            map = map.adding(key: "access", value: accessValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case lastInitiatedAt
            case status
            case access
        }
    }

    public struct StateMetadata: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.ageassurance.defs#stateMetadata"
        public let accountCreatedAt: ATProtocolDate?

        /// Standard initializer
        public init(
            accountCreatedAt: ATProtocolDate?
        ) {
            self.accountCreatedAt = accountCreatedAt
        }

        /// Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                accountCreatedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .accountCreatedAt)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'accountCreatedAt': \(error)")

                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(accountCreatedAt, forKey: .accountCreatedAt)
        }

        public func hash(into hasher: inout Hasher) {
            if let value = accountCreatedAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if accountCreatedAt != other.accountCreatedAt {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            if let value = accountCreatedAt {
                // Encode optional property even if it's an empty array for CBOR

                let accountCreatedAtValue = try value.toCBORValue()
                map = map.adding(key: "accountCreatedAt", value: accountCreatedAtValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case accountCreatedAt
        }
    }

    public struct Config: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.ageassurance.defs#config"
        public let regions: [AppBskyAgeassuranceDefs.ConfigRegion]

        /// Standard initializer
        public init(
            regions: [AppBskyAgeassuranceDefs.ConfigRegion]
        ) {
            self.regions = regions
        }

        /// Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                regions = try container.decode([AppBskyAgeassuranceDefs.ConfigRegion].self, forKey: .regions)

            } catch {
                LogManager.logError("Decoding error for required property 'regions': \(error)")

                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(regions, forKey: .regions)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(regions)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if regions != other.regions {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let regionsValue = try regions.toCBORValue()
            map = map.adding(key: "regions", value: regionsValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case regions
        }
    }

    public struct ConfigRegion: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.ageassurance.defs#configRegion"
        public let countryCode: String
        public let regionCode: String?
        public let minAccessAge: Int
        public let rules: [ConfigRegionRulesUnion]

        /// Standard initializer
        public init(
            countryCode: String, regionCode: String?, minAccessAge: Int, rules: [ConfigRegionRulesUnion]
        ) {
            self.countryCode = countryCode
            self.regionCode = regionCode
            self.minAccessAge = minAccessAge
            self.rules = rules
        }

        /// Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                countryCode = try container.decode(String.self, forKey: .countryCode)

            } catch {
                LogManager.logError("Decoding error for required property 'countryCode': \(error)")

                throw error
            }
            do {
                regionCode = try container.decodeIfPresent(String.self, forKey: .regionCode)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'regionCode': \(error)")

                throw error
            }
            do {
                minAccessAge = try container.decode(Int.self, forKey: .minAccessAge)

            } catch {
                LogManager.logError("Decoding error for required property 'minAccessAge': \(error)")

                throw error
            }
            do {
                rules = try container.decode([ConfigRegionRulesUnion].self, forKey: .rules)

            } catch {
                LogManager.logError("Decoding error for required property 'rules': \(error)")

                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(countryCode, forKey: .countryCode)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(regionCode, forKey: .regionCode)

            try container.encode(minAccessAge, forKey: .minAccessAge)

            try container.encode(rules, forKey: .rules)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(countryCode)
            if let value = regionCode {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(minAccessAge)
            hasher.combine(rules)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if countryCode != other.countryCode {
                return false
            }

            if regionCode != other.regionCode {
                return false
            }

            if minAccessAge != other.minAccessAge {
                return false
            }

            if rules != other.rules {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let countryCodeValue = try countryCode.toCBORValue()
            map = map.adding(key: "countryCode", value: countryCodeValue)

            if let value = regionCode {
                // Encode optional property even if it's an empty array for CBOR

                let regionCodeValue = try value.toCBORValue()
                map = map.adding(key: "regionCode", value: regionCodeValue)
            }

            let minAccessAgeValue = try minAccessAge.toCBORValue()
            map = map.adding(key: "minAccessAge", value: minAccessAgeValue)

            let rulesValue = try rules.toCBORValue()
            map = map.adding(key: "rules", value: rulesValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case countryCode
            case regionCode
            case minAccessAge
            case rules
        }
    }

    public struct ConfigRegionRuleDefault: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.ageassurance.defs#configRegionRuleDefault"
        public let access: AppBskyAgeassuranceDefs.Access

        /// Standard initializer
        public init(
            access: AppBskyAgeassuranceDefs.Access
        ) {
            self.access = access
        }

        /// Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                access = try container.decode(AppBskyAgeassuranceDefs.Access.self, forKey: .access)

            } catch {
                LogManager.logError("Decoding error for required property 'access': \(error)")

                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(access, forKey: .access)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(access)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if access != other.access {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let accessValue = try access.toCBORValue()
            map = map.adding(key: "access", value: accessValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case access
        }
    }

    public struct ConfigRegionRuleIfDeclaredOverAge: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.ageassurance.defs#configRegionRuleIfDeclaredOverAge"
        public let age: Int
        public let access: AppBskyAgeassuranceDefs.Access

        /// Standard initializer
        public init(
            age: Int, access: AppBskyAgeassuranceDefs.Access
        ) {
            self.age = age
            self.access = access
        }

        /// Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                age = try container.decode(Int.self, forKey: .age)

            } catch {
                LogManager.logError("Decoding error for required property 'age': \(error)")

                throw error
            }
            do {
                access = try container.decode(AppBskyAgeassuranceDefs.Access.self, forKey: .access)

            } catch {
                LogManager.logError("Decoding error for required property 'access': \(error)")

                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(age, forKey: .age)

            try container.encode(access, forKey: .access)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(age)
            hasher.combine(access)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if age != other.age {
                return false
            }

            if access != other.access {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let ageValue = try age.toCBORValue()
            map = map.adding(key: "age", value: ageValue)

            let accessValue = try access.toCBORValue()
            map = map.adding(key: "access", value: accessValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case age
            case access
        }
    }

    public struct ConfigRegionRuleIfDeclaredUnderAge: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.ageassurance.defs#configRegionRuleIfDeclaredUnderAge"
        public let age: Int
        public let access: AppBskyAgeassuranceDefs.Access

        /// Standard initializer
        public init(
            age: Int, access: AppBskyAgeassuranceDefs.Access
        ) {
            self.age = age
            self.access = access
        }

        /// Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                age = try container.decode(Int.self, forKey: .age)

            } catch {
                LogManager.logError("Decoding error for required property 'age': \(error)")

                throw error
            }
            do {
                access = try container.decode(AppBskyAgeassuranceDefs.Access.self, forKey: .access)

            } catch {
                LogManager.logError("Decoding error for required property 'access': \(error)")

                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(age, forKey: .age)

            try container.encode(access, forKey: .access)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(age)
            hasher.combine(access)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if age != other.age {
                return false
            }

            if access != other.access {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let ageValue = try age.toCBORValue()
            map = map.adding(key: "age", value: ageValue)

            let accessValue = try access.toCBORValue()
            map = map.adding(key: "access", value: accessValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case age
            case access
        }
    }

    public struct ConfigRegionRuleIfAssuredOverAge: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.ageassurance.defs#configRegionRuleIfAssuredOverAge"
        public let age: Int
        public let access: AppBskyAgeassuranceDefs.Access

        /// Standard initializer
        public init(
            age: Int, access: AppBskyAgeassuranceDefs.Access
        ) {
            self.age = age
            self.access = access
        }

        /// Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                age = try container.decode(Int.self, forKey: .age)

            } catch {
                LogManager.logError("Decoding error for required property 'age': \(error)")

                throw error
            }
            do {
                access = try container.decode(AppBskyAgeassuranceDefs.Access.self, forKey: .access)

            } catch {
                LogManager.logError("Decoding error for required property 'access': \(error)")

                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(age, forKey: .age)

            try container.encode(access, forKey: .access)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(age)
            hasher.combine(access)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if age != other.age {
                return false
            }

            if access != other.access {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let ageValue = try age.toCBORValue()
            map = map.adding(key: "age", value: ageValue)

            let accessValue = try access.toCBORValue()
            map = map.adding(key: "access", value: accessValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case age
            case access
        }
    }

    public struct ConfigRegionRuleIfAssuredUnderAge: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.ageassurance.defs#configRegionRuleIfAssuredUnderAge"
        public let age: Int
        public let access: AppBskyAgeassuranceDefs.Access

        /// Standard initializer
        public init(
            age: Int, access: AppBskyAgeassuranceDefs.Access
        ) {
            self.age = age
            self.access = access
        }

        /// Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                age = try container.decode(Int.self, forKey: .age)

            } catch {
                LogManager.logError("Decoding error for required property 'age': \(error)")

                throw error
            }
            do {
                access = try container.decode(AppBskyAgeassuranceDefs.Access.self, forKey: .access)

            } catch {
                LogManager.logError("Decoding error for required property 'access': \(error)")

                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(age, forKey: .age)

            try container.encode(access, forKey: .access)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(age)
            hasher.combine(access)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if age != other.age {
                return false
            }

            if access != other.access {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let ageValue = try age.toCBORValue()
            map = map.adding(key: "age", value: ageValue)

            let accessValue = try access.toCBORValue()
            map = map.adding(key: "access", value: accessValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case age
            case access
        }
    }

    public struct ConfigRegionRuleIfAccountNewerThan: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.ageassurance.defs#configRegionRuleIfAccountNewerThan"
        public let date: ATProtocolDate
        public let access: AppBskyAgeassuranceDefs.Access

        /// Standard initializer
        public init(
            date: ATProtocolDate, access: AppBskyAgeassuranceDefs.Access
        ) {
            self.date = date
            self.access = access
        }

        /// Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                date = try container.decode(ATProtocolDate.self, forKey: .date)

            } catch {
                LogManager.logError("Decoding error for required property 'date': \(error)")

                throw error
            }
            do {
                access = try container.decode(AppBskyAgeassuranceDefs.Access.self, forKey: .access)

            } catch {
                LogManager.logError("Decoding error for required property 'access': \(error)")

                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(date, forKey: .date)

            try container.encode(access, forKey: .access)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(date)
            hasher.combine(access)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if date != other.date {
                return false
            }

            if access != other.access {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let dateValue = try date.toCBORValue()
            map = map.adding(key: "date", value: dateValue)

            let accessValue = try access.toCBORValue()
            map = map.adding(key: "access", value: accessValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case date
            case access
        }
    }

    public struct ConfigRegionRuleIfAccountOlderThan: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.ageassurance.defs#configRegionRuleIfAccountOlderThan"
        public let date: ATProtocolDate
        public let access: AppBskyAgeassuranceDefs.Access

        /// Standard initializer
        public init(
            date: ATProtocolDate, access: AppBskyAgeassuranceDefs.Access
        ) {
            self.date = date
            self.access = access
        }

        /// Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                date = try container.decode(ATProtocolDate.self, forKey: .date)

            } catch {
                LogManager.logError("Decoding error for required property 'date': \(error)")

                throw error
            }
            do {
                access = try container.decode(AppBskyAgeassuranceDefs.Access.self, forKey: .access)

            } catch {
                LogManager.logError("Decoding error for required property 'access': \(error)")

                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(date, forKey: .date)

            try container.encode(access, forKey: .access)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(date)
            hasher.combine(access)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if date != other.date {
                return false
            }

            if access != other.access {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let dateValue = try date.toCBORValue()
            map = map.adding(key: "date", value: dateValue)

            let accessValue = try access.toCBORValue()
            map = map.adding(key: "access", value: accessValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case date
            case access
        }
    }

    public struct Event: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.ageassurance.defs#event"
        public let createdAt: ATProtocolDate
        public let attemptId: String
        public let status: String
        public let access: String
        public let countryCode: String
        public let regionCode: String?
        public let email: String?
        public let initIp: String?
        public let initUa: String?
        public let completeIp: String?
        public let completeUa: String?

        /// Standard initializer
        public init(
            createdAt: ATProtocolDate, attemptId: String, status: String, access: String, countryCode: String, regionCode: String?, email: String?, initIp: String?, initUa: String?, completeIp: String?, completeUa: String?
        ) {
            self.createdAt = createdAt
            self.attemptId = attemptId
            self.status = status
            self.access = access
            self.countryCode = countryCode
            self.regionCode = regionCode
            self.email = email
            self.initIp = initIp
            self.initUa = initUa
            self.completeIp = completeIp
            self.completeUa = completeUa
        }

        /// Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)

            } catch {
                LogManager.logError("Decoding error for required property 'createdAt': \(error)")

                throw error
            }
            do {
                attemptId = try container.decode(String.self, forKey: .attemptId)

            } catch {
                LogManager.logError("Decoding error for required property 'attemptId': \(error)")

                throw error
            }
            do {
                status = try container.decode(String.self, forKey: .status)

            } catch {
                LogManager.logError("Decoding error for required property 'status': \(error)")

                throw error
            }
            do {
                access = try container.decode(String.self, forKey: .access)

            } catch {
                LogManager.logError("Decoding error for required property 'access': \(error)")

                throw error
            }
            do {
                countryCode = try container.decode(String.self, forKey: .countryCode)

            } catch {
                LogManager.logError("Decoding error for required property 'countryCode': \(error)")

                throw error
            }
            do {
                regionCode = try container.decodeIfPresent(String.self, forKey: .regionCode)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'regionCode': \(error)")

                throw error
            }
            do {
                email = try container.decodeIfPresent(String.self, forKey: .email)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'email': \(error)")

                throw error
            }
            do {
                initIp = try container.decodeIfPresent(String.self, forKey: .initIp)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'initIp': \(error)")

                throw error
            }
            do {
                initUa = try container.decodeIfPresent(String.self, forKey: .initUa)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'initUa': \(error)")

                throw error
            }
            do {
                completeIp = try container.decodeIfPresent(String.self, forKey: .completeIp)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'completeIp': \(error)")

                throw error
            }
            do {
                completeUa = try container.decodeIfPresent(String.self, forKey: .completeUa)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'completeUa': \(error)")

                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(createdAt, forKey: .createdAt)

            try container.encode(attemptId, forKey: .attemptId)

            try container.encode(status, forKey: .status)

            try container.encode(access, forKey: .access)

            try container.encode(countryCode, forKey: .countryCode)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(regionCode, forKey: .regionCode)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(email, forKey: .email)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(initIp, forKey: .initIp)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(initUa, forKey: .initUa)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(completeIp, forKey: .completeIp)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(completeUa, forKey: .completeUa)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(createdAt)
            hasher.combine(attemptId)
            hasher.combine(status)
            hasher.combine(access)
            hasher.combine(countryCode)
            if let value = regionCode {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = email {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = initIp {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = initUa {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = completeIp {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = completeUa {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if createdAt != other.createdAt {
                return false
            }

            if attemptId != other.attemptId {
                return false
            }

            if status != other.status {
                return false
            }

            if access != other.access {
                return false
            }

            if countryCode != other.countryCode {
                return false
            }

            if regionCode != other.regionCode {
                return false
            }

            if email != other.email {
                return false
            }

            if initIp != other.initIp {
                return false
            }

            if initUa != other.initUa {
                return false
            }

            if completeIp != other.completeIp {
                return false
            }

            if completeUa != other.completeUa {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)

            let attemptIdValue = try attemptId.toCBORValue()
            map = map.adding(key: "attemptId", value: attemptIdValue)

            let statusValue = try status.toCBORValue()
            map = map.adding(key: "status", value: statusValue)

            let accessValue = try access.toCBORValue()
            map = map.adding(key: "access", value: accessValue)

            let countryCodeValue = try countryCode.toCBORValue()
            map = map.adding(key: "countryCode", value: countryCodeValue)

            if let value = regionCode {
                // Encode optional property even if it's an empty array for CBOR

                let regionCodeValue = try value.toCBORValue()
                map = map.adding(key: "regionCode", value: regionCodeValue)
            }

            if let value = email {
                // Encode optional property even if it's an empty array for CBOR

                let emailValue = try value.toCBORValue()
                map = map.adding(key: "email", value: emailValue)
            }

            if let value = initIp {
                // Encode optional property even if it's an empty array for CBOR

                let initIpValue = try value.toCBORValue()
                map = map.adding(key: "initIp", value: initIpValue)
            }

            if let value = initUa {
                // Encode optional property even if it's an empty array for CBOR

                let initUaValue = try value.toCBORValue()
                map = map.adding(key: "initUa", value: initUaValue)
            }

            if let value = completeIp {
                // Encode optional property even if it's an empty array for CBOR

                let completeIpValue = try value.toCBORValue()
                map = map.adding(key: "completeIp", value: completeIpValue)
            }

            if let value = completeUa {
                // Encode optional property even if it's an empty array for CBOR

                let completeUaValue = try value.toCBORValue()
                map = map.adding(key: "completeUa", value: completeUaValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case createdAt
            case attemptId
            case status
            case access
            case countryCode
            case regionCode
            case email
            case initIp
            case initUa
            case completeIp
            case completeUa
        }
    }

    public struct Access: Codable, ATProtocolCodable, ATProtocolValue {
        public let rawValue: String

        /// Predefined constants
        ///
        public static let unknown = Access(rawValue: "unknown")
        ///
        public static let none = Access(rawValue: "none")
        ///
        public static let safe = Access(rawValue: "safe")
        ///
        public static let full = Access(rawValue: "full")

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
            guard let otherValue = other as? Access else { return false }
            return rawValue == otherValue.rawValue
        }

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // For string-based enum types, we return the raw string value directly
            return rawValue
        }

        /// Provide allCases-like functionality
        public static var predefinedValues: [Access] {
            return [
                .unknown,
                .none,
                .safe,
                .full,
            ]
        }
    }

    public struct Status: Codable, ATProtocolCodable, ATProtocolValue {
        public let rawValue: String

        /// Predefined constants
        ///
        public static let unknown = Status(rawValue: "unknown")
        ///
        public static let pending = Status(rawValue: "pending")
        ///
        public static let assured = Status(rawValue: "assured")
        ///
        public static let blocked = Status(rawValue: "blocked")

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
            guard let otherValue = other as? Status else { return false }
            return rawValue == otherValue.rawValue
        }

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // For string-based enum types, we return the raw string value directly
            return rawValue
        }

        /// Provide allCases-like functionality
        public static var predefinedValues: [Status] {
            return [
                .unknown,
                .pending,
                .assured,
                .blocked,
            ]
        }
    }

    public enum ConfigRegionRulesUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case appBskyAgeassuranceDefsConfigRegionRuleDefault(AppBskyAgeassuranceDefs.ConfigRegionRuleDefault)
        case appBskyAgeassuranceDefsConfigRegionRuleIfDeclaredOverAge(AppBskyAgeassuranceDefs.ConfigRegionRuleIfDeclaredOverAge)
        case appBskyAgeassuranceDefsConfigRegionRuleIfDeclaredUnderAge(AppBskyAgeassuranceDefs.ConfigRegionRuleIfDeclaredUnderAge)
        case appBskyAgeassuranceDefsConfigRegionRuleIfAssuredOverAge(AppBskyAgeassuranceDefs.ConfigRegionRuleIfAssuredOverAge)
        case appBskyAgeassuranceDefsConfigRegionRuleIfAssuredUnderAge(AppBskyAgeassuranceDefs.ConfigRegionRuleIfAssuredUnderAge)
        case appBskyAgeassuranceDefsConfigRegionRuleIfAccountNewerThan(AppBskyAgeassuranceDefs.ConfigRegionRuleIfAccountNewerThan)
        case appBskyAgeassuranceDefsConfigRegionRuleIfAccountOlderThan(AppBskyAgeassuranceDefs.ConfigRegionRuleIfAccountOlderThan)
        case unexpected(ATProtocolValueContainer)
        public init(_ value: AppBskyAgeassuranceDefs.ConfigRegionRuleDefault) {
            self = .appBskyAgeassuranceDefsConfigRegionRuleDefault(value)
        }

        public init(_ value: AppBskyAgeassuranceDefs.ConfigRegionRuleIfDeclaredOverAge) {
            self = .appBskyAgeassuranceDefsConfigRegionRuleIfDeclaredOverAge(value)
        }

        public init(_ value: AppBskyAgeassuranceDefs.ConfigRegionRuleIfDeclaredUnderAge) {
            self = .appBskyAgeassuranceDefsConfigRegionRuleIfDeclaredUnderAge(value)
        }

        public init(_ value: AppBskyAgeassuranceDefs.ConfigRegionRuleIfAssuredOverAge) {
            self = .appBskyAgeassuranceDefsConfigRegionRuleIfAssuredOverAge(value)
        }

        public init(_ value: AppBskyAgeassuranceDefs.ConfigRegionRuleIfAssuredUnderAge) {
            self = .appBskyAgeassuranceDefsConfigRegionRuleIfAssuredUnderAge(value)
        }

        public init(_ value: AppBskyAgeassuranceDefs.ConfigRegionRuleIfAccountNewerThan) {
            self = .appBskyAgeassuranceDefsConfigRegionRuleIfAccountNewerThan(value)
        }

        public init(_ value: AppBskyAgeassuranceDefs.ConfigRegionRuleIfAccountOlderThan) {
            self = .appBskyAgeassuranceDefsConfigRegionRuleIfAccountOlderThan(value)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            switch typeValue {
            case "app.bsky.ageassurance.defs#configRegionRuleDefault":
                let value = try AppBskyAgeassuranceDefs.ConfigRegionRuleDefault(from: decoder)
                self = .appBskyAgeassuranceDefsConfigRegionRuleDefault(value)
            case "app.bsky.ageassurance.defs#configRegionRuleIfDeclaredOverAge":
                let value = try AppBskyAgeassuranceDefs.ConfigRegionRuleIfDeclaredOverAge(from: decoder)
                self = .appBskyAgeassuranceDefsConfigRegionRuleIfDeclaredOverAge(value)
            case "app.bsky.ageassurance.defs#configRegionRuleIfDeclaredUnderAge":
                let value = try AppBskyAgeassuranceDefs.ConfigRegionRuleIfDeclaredUnderAge(from: decoder)
                self = .appBskyAgeassuranceDefsConfigRegionRuleIfDeclaredUnderAge(value)
            case "app.bsky.ageassurance.defs#configRegionRuleIfAssuredOverAge":
                let value = try AppBskyAgeassuranceDefs.ConfigRegionRuleIfAssuredOverAge(from: decoder)
                self = .appBskyAgeassuranceDefsConfigRegionRuleIfAssuredOverAge(value)
            case "app.bsky.ageassurance.defs#configRegionRuleIfAssuredUnderAge":
                let value = try AppBskyAgeassuranceDefs.ConfigRegionRuleIfAssuredUnderAge(from: decoder)
                self = .appBskyAgeassuranceDefsConfigRegionRuleIfAssuredUnderAge(value)
            case "app.bsky.ageassurance.defs#configRegionRuleIfAccountNewerThan":
                let value = try AppBskyAgeassuranceDefs.ConfigRegionRuleIfAccountNewerThan(from: decoder)
                self = .appBskyAgeassuranceDefsConfigRegionRuleIfAccountNewerThan(value)
            case "app.bsky.ageassurance.defs#configRegionRuleIfAccountOlderThan":
                let value = try AppBskyAgeassuranceDefs.ConfigRegionRuleIfAccountOlderThan(from: decoder)
                self = .appBskyAgeassuranceDefsConfigRegionRuleIfAccountOlderThan(value)
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .appBskyAgeassuranceDefsConfigRegionRuleDefault(value):
                try container.encode("app.bsky.ageassurance.defs#configRegionRuleDefault", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyAgeassuranceDefsConfigRegionRuleIfDeclaredOverAge(value):
                try container.encode("app.bsky.ageassurance.defs#configRegionRuleIfDeclaredOverAge", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyAgeassuranceDefsConfigRegionRuleIfDeclaredUnderAge(value):
                try container.encode("app.bsky.ageassurance.defs#configRegionRuleIfDeclaredUnderAge", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyAgeassuranceDefsConfigRegionRuleIfAssuredOverAge(value):
                try container.encode("app.bsky.ageassurance.defs#configRegionRuleIfAssuredOverAge", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyAgeassuranceDefsConfigRegionRuleIfAssuredUnderAge(value):
                try container.encode("app.bsky.ageassurance.defs#configRegionRuleIfAssuredUnderAge", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyAgeassuranceDefsConfigRegionRuleIfAccountNewerThan(value):
                try container.encode("app.bsky.ageassurance.defs#configRegionRuleIfAccountNewerThan", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyAgeassuranceDefsConfigRegionRuleIfAccountOlderThan(value):
                try container.encode("app.bsky.ageassurance.defs#configRegionRuleIfAccountOlderThan", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .appBskyAgeassuranceDefsConfigRegionRuleDefault(value):
                hasher.combine("app.bsky.ageassurance.defs#configRegionRuleDefault")
                hasher.combine(value)
            case let .appBskyAgeassuranceDefsConfigRegionRuleIfDeclaredOverAge(value):
                hasher.combine("app.bsky.ageassurance.defs#configRegionRuleIfDeclaredOverAge")
                hasher.combine(value)
            case let .appBskyAgeassuranceDefsConfigRegionRuleIfDeclaredUnderAge(value):
                hasher.combine("app.bsky.ageassurance.defs#configRegionRuleIfDeclaredUnderAge")
                hasher.combine(value)
            case let .appBskyAgeassuranceDefsConfigRegionRuleIfAssuredOverAge(value):
                hasher.combine("app.bsky.ageassurance.defs#configRegionRuleIfAssuredOverAge")
                hasher.combine(value)
            case let .appBskyAgeassuranceDefsConfigRegionRuleIfAssuredUnderAge(value):
                hasher.combine("app.bsky.ageassurance.defs#configRegionRuleIfAssuredUnderAge")
                hasher.combine(value)
            case let .appBskyAgeassuranceDefsConfigRegionRuleIfAccountNewerThan(value):
                hasher.combine("app.bsky.ageassurance.defs#configRegionRuleIfAccountNewerThan")
                hasher.combine(value)
            case let .appBskyAgeassuranceDefsConfigRegionRuleIfAccountOlderThan(value):
                hasher.combine("app.bsky.ageassurance.defs#configRegionRuleIfAccountOlderThan")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: ConfigRegionRulesUnion, rhs: ConfigRegionRulesUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .appBskyAgeassuranceDefsConfigRegionRuleDefault(lhsValue),
                .appBskyAgeassuranceDefsConfigRegionRuleDefault(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyAgeassuranceDefsConfigRegionRuleIfDeclaredOverAge(lhsValue),
                .appBskyAgeassuranceDefsConfigRegionRuleIfDeclaredOverAge(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyAgeassuranceDefsConfigRegionRuleIfDeclaredUnderAge(lhsValue),
                .appBskyAgeassuranceDefsConfigRegionRuleIfDeclaredUnderAge(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyAgeassuranceDefsConfigRegionRuleIfAssuredOverAge(lhsValue),
                .appBskyAgeassuranceDefsConfigRegionRuleIfAssuredOverAge(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyAgeassuranceDefsConfigRegionRuleIfAssuredUnderAge(lhsValue),
                .appBskyAgeassuranceDefsConfigRegionRuleIfAssuredUnderAge(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyAgeassuranceDefsConfigRegionRuleIfAccountNewerThan(lhsValue),
                .appBskyAgeassuranceDefsConfigRegionRuleIfAccountNewerThan(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyAgeassuranceDefsConfigRegionRuleIfAccountOlderThan(lhsValue),
                .appBskyAgeassuranceDefsConfigRegionRuleIfAccountOlderThan(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? ConfigRegionRulesUnion else { return false }
            return self == other
        }

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .appBskyAgeassuranceDefsConfigRegionRuleDefault(value):
                map = map.adding(key: "$type", value: "app.bsky.ageassurance.defs#configRegionRuleDefault")

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
            case let .appBskyAgeassuranceDefsConfigRegionRuleIfDeclaredOverAge(value):
                map = map.adding(key: "$type", value: "app.bsky.ageassurance.defs#configRegionRuleIfDeclaredOverAge")

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
            case let .appBskyAgeassuranceDefsConfigRegionRuleIfDeclaredUnderAge(value):
                map = map.adding(key: "$type", value: "app.bsky.ageassurance.defs#configRegionRuleIfDeclaredUnderAge")

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
            case let .appBskyAgeassuranceDefsConfigRegionRuleIfAssuredOverAge(value):
                map = map.adding(key: "$type", value: "app.bsky.ageassurance.defs#configRegionRuleIfAssuredOverAge")

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
            case let .appBskyAgeassuranceDefsConfigRegionRuleIfAssuredUnderAge(value):
                map = map.adding(key: "$type", value: "app.bsky.ageassurance.defs#configRegionRuleIfAssuredUnderAge")

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
            case let .appBskyAgeassuranceDefsConfigRegionRuleIfAccountNewerThan(value):
                map = map.adding(key: "$type", value: "app.bsky.ageassurance.defs#configRegionRuleIfAccountNewerThan")

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
            case let .appBskyAgeassuranceDefsConfigRegionRuleIfAccountOlderThan(value):
                map = map.adding(key: "$type", value: "app.bsky.ageassurance.defs#configRegionRuleIfAccountOlderThan")

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
