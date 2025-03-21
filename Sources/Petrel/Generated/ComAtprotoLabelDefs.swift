import Foundation

// lexicon: 1, id: com.atproto.label.defs

public enum ComAtprotoLabelDefs {
    public static let typeIdentifier = "com.atproto.label.defs"

    public struct Label: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "com.atproto.label.defs#label"
        public let ver: Int?
        public let src: String
        public let uri: URI
        public let cid: String?
        public let val: String
        public let neg: Bool?
        public let cts: ATProtocolDate
        public let exp: ATProtocolDate?
        public let sig: Bytes?

        // Standard initializer
        public init(
            ver: Int?, src: String, uri: URI, cid: String?, val: String, neg: Bool?, cts: ATProtocolDate, exp: ATProtocolDate?, sig: Bytes?
        ) {
            self.ver = ver
            self.src = src
            self.uri = uri
            self.cid = cid
            self.val = val
            self.neg = neg
            self.cts = cts
            self.exp = exp
            self.sig = sig
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                ver = try container.decodeIfPresent(Int.self, forKey: .ver)

            } catch {
                LogManager.logError("Decoding error for property 'ver': \(error)")
                throw error
            }
            do {
                src = try container.decode(String.self, forKey: .src)

            } catch {
                LogManager.logError("Decoding error for property 'src': \(error)")
                throw error
            }
            do {
                uri = try container.decode(URI.self, forKey: .uri)

            } catch {
                LogManager.logError("Decoding error for property 'uri': \(error)")
                throw error
            }
            do {
                cid = try container.decodeIfPresent(String.self, forKey: .cid)

            } catch {
                LogManager.logError("Decoding error for property 'cid': \(error)")
                throw error
            }
            do {
                val = try container.decode(String.self, forKey: .val)

            } catch {
                LogManager.logError("Decoding error for property 'val': \(error)")
                throw error
            }
            do {
                neg = try container.decodeIfPresent(Bool.self, forKey: .neg)

            } catch {
                LogManager.logError("Decoding error for property 'neg': \(error)")
                throw error
            }
            do {
                cts = try container.decode(ATProtocolDate.self, forKey: .cts)

            } catch {
                LogManager.logError("Decoding error for property 'cts': \(error)")
                throw error
            }
            do {
                exp = try container.decodeIfPresent(ATProtocolDate.self, forKey: .exp)

            } catch {
                LogManager.logError("Decoding error for property 'exp': \(error)")
                throw error
            }
            do {
                sig = try container.decodeIfPresent(Bytes.self, forKey: .sig)

            } catch {
                LogManager.logError("Decoding error for property 'sig': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            if let value = ver {
                try container.encode(value, forKey: .ver)
            }

            try container.encode(src, forKey: .src)

            try container.encode(uri, forKey: .uri)

            if let value = cid {
                try container.encode(value, forKey: .cid)
            }

            try container.encode(val, forKey: .val)

            if let value = neg {
                try container.encode(value, forKey: .neg)
            }

            try container.encode(cts, forKey: .cts)

            if let value = exp {
                try container.encode(value, forKey: .exp)
            }

            if let value = sig {
                try container.encode(value, forKey: .sig)
            }
        }

        public func hash(into hasher: inout Hasher) {
            if let value = ver {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(src)
            hasher.combine(uri)
            if let value = cid {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(val)
            if let value = neg {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(cts)
            if let value = exp {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = sig {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if ver != other.ver {
                return false
            }

            if src != other.src {
                return false
            }

            if uri != other.uri {
                return false
            }

            if cid != other.cid {
                return false
            }

            if val != other.val {
                return false
            }

            if neg != other.neg {
                return false
            }

            if cts != other.cts {
                return false
            }

            if exp != other.exp {
                return false
            }

            if sig != other.sig {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case ver
            case src
            case uri
            case cid
            case val
            case neg
            case cts
            case exp
            case sig
        }
    }

    public struct SelfLabels: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "com.atproto.label.defs#selfLabels"
        public let values: [SelfLabel]

        // Standard initializer
        public init(
            values: [SelfLabel]
        ) {
            self.values = values
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                values = try container.decode([SelfLabel].self, forKey: .values)

            } catch {
                LogManager.logError("Decoding error for property 'values': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(values, forKey: .values)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(values)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if values != other.values {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case values
        }
    }

    public struct SelfLabel: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "com.atproto.label.defs#selfLabel"
        public let val: String

        // Standard initializer
        public init(
            val: String
        ) {
            self.val = val
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                val = try container.decode(String.self, forKey: .val)

            } catch {
                LogManager.logError("Decoding error for property 'val': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(val, forKey: .val)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(val)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if val != other.val {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case val
        }
    }

    public struct LabelValueDefinition: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "com.atproto.label.defs#labelValueDefinition"
        public let identifier: String
        public let severity: String
        public let blurs: String
        public let defaultSetting: String?
        public let adultOnly: Bool?
        public let locales: [LabelValueDefinitionStrings]

        // Standard initializer
        public init(
            identifier: String, severity: String, blurs: String, defaultSetting: String?, adultOnly: Bool?, locales: [LabelValueDefinitionStrings]
        ) {
            self.identifier = identifier
            self.severity = severity
            self.blurs = blurs
            self.defaultSetting = defaultSetting
            self.adultOnly = adultOnly
            self.locales = locales
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                identifier = try container.decode(String.self, forKey: .identifier)

            } catch {
                LogManager.logError("Decoding error for property 'identifier': \(error)")
                throw error
            }
            do {
                severity = try container.decode(String.self, forKey: .severity)

            } catch {
                LogManager.logError("Decoding error for property 'severity': \(error)")
                throw error
            }
            do {
                blurs = try container.decode(String.self, forKey: .blurs)

            } catch {
                LogManager.logError("Decoding error for property 'blurs': \(error)")
                throw error
            }
            do {
                defaultSetting = try container.decodeIfPresent(String.self, forKey: .defaultSetting)

            } catch {
                LogManager.logError("Decoding error for property 'defaultSetting': \(error)")
                throw error
            }
            do {
                adultOnly = try container.decodeIfPresent(Bool.self, forKey: .adultOnly)

            } catch {
                LogManager.logError("Decoding error for property 'adultOnly': \(error)")
                throw error
            }
            do {
                locales = try container.decode([LabelValueDefinitionStrings].self, forKey: .locales)

            } catch {
                LogManager.logError("Decoding error for property 'locales': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(identifier, forKey: .identifier)

            try container.encode(severity, forKey: .severity)

            try container.encode(blurs, forKey: .blurs)

            if let value = defaultSetting {
                try container.encode(value, forKey: .defaultSetting)
            }

            if let value = adultOnly {
                try container.encode(value, forKey: .adultOnly)
            }

            try container.encode(locales, forKey: .locales)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(identifier)
            hasher.combine(severity)
            hasher.combine(blurs)
            if let value = defaultSetting {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = adultOnly {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(locales)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if identifier != other.identifier {
                return false
            }

            if severity != other.severity {
                return false
            }

            if blurs != other.blurs {
                return false
            }

            if defaultSetting != other.defaultSetting {
                return false
            }

            if adultOnly != other.adultOnly {
                return false
            }

            if locales != other.locales {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case identifier
            case severity
            case blurs
            case defaultSetting
            case adultOnly
            case locales
        }
    }

    public struct LabelValueDefinitionStrings: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "com.atproto.label.defs#labelValueDefinitionStrings"
        public let lang: LanguageCodeContainer
        public let name: String
        public let description: String

        // Standard initializer
        public init(
            lang: LanguageCodeContainer, name: String, description: String
        ) {
            self.lang = lang
            self.name = name
            self.description = description
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                lang = try container.decode(LanguageCodeContainer.self, forKey: .lang)

            } catch {
                LogManager.logError("Decoding error for property 'lang': \(error)")
                throw error
            }
            do {
                name = try container.decode(String.self, forKey: .name)

            } catch {
                LogManager.logError("Decoding error for property 'name': \(error)")
                throw error
            }
            do {
                description = try container.decode(String.self, forKey: .description)

            } catch {
                LogManager.logError("Decoding error for property 'description': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(lang, forKey: .lang)

            try container.encode(name, forKey: .name)

            try container.encode(description, forKey: .description)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(lang)
            hasher.combine(name)
            hasher.combine(description)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if lang != other.lang {
                return false
            }

            if name != other.name {
                return false
            }

            if description != other.description {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case lang
            case name
            case description
        }
    }

    public struct LabelValue: Codable, ATProtocolCodable, ATProtocolValue {
        public let rawValue: String

        // Predefined constants
        //
        public static let !hide = LabelValue(rawValue: "!hide")
        //
        public static let !no - promote = LabelValue(rawValue: "!no-promote")
        //
        public static let !warn = LabelValue(rawValue: "!warn")
        //
        public static let !no - unauthenticated = LabelValue(rawValue: "!no-unauthenticated")
        //
        public static let dmca - violation = LabelValue(rawValue: "dmca-violation")
        //
        public static let doxxing = LabelValue(rawValue: "doxxing")
        //
        public static let porn = LabelValue(rawValue: "porn")
        //
        public static let sexual = LabelValue(rawValue: "sexual")
        //
        public static let nudity = LabelValue(rawValue: "nudity")
        //
        public static let nsfl = LabelValue(rawValue: "nsfl")
        //
        public static let gore = LabelValue(rawValue: "gore")

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
            guard let otherValue = other as? LabelValue else { return false }
            return rawValue == otherValue.rawValue
        }

        // Provide allCases-like functionality
        public static var predefinedValues: [LabelValue] {
            return [
                .!hide,
                .!no - promote,
                .!warn,
                .!no - unauthenticated,
                .dmca - violation,
                .doxxing,
                .porn,
                .sexual,
                .nudity,
                .nsfl,
                .gore,
            ]
        }
    }
}
