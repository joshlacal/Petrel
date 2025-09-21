import Foundation

// lexicon: 1, id: com.atproto.label.defs

public enum ComAtprotoLabelDefs {
    public static let typeIdentifier = "com.atproto.label.defs"

    public struct Label: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "com.atproto.label.defs#label"
        public let ver: Int?
        public let src: DID
        public let uri: URI
        public let cid: CID?
        public let val: String
        public let neg: Bool?
        public let cts: ATProtocolDate
        public let exp: ATProtocolDate?
        public let sig: Bytes?

        // Standard initializer
        public init(
            ver: Int?, src: DID, uri: URI, cid: CID?, val: String, neg: Bool?, cts: ATProtocolDate, exp: ATProtocolDate?, sig: Bytes?
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
                LogManager.logDebug("Decoding error for optional property 'ver': \(error)")

                throw error
            }
            do {
                src = try container.decode(DID.self, forKey: .src)

            } catch {
                LogManager.logError("Decoding error for required property 'src': \(error)")

                throw error
            }
            do {
                uri = try container.decode(URI.self, forKey: .uri)

            } catch {
                LogManager.logError("Decoding error for required property 'uri': \(error)")

                throw error
            }
            do {
                cid = try container.decodeIfPresent(CID.self, forKey: .cid)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'cid': \(error)")

                throw error
            }
            do {
                val = try container.decode(String.self, forKey: .val)

            } catch {
                LogManager.logError("Decoding error for required property 'val': \(error)")

                throw error
            }
            do {
                neg = try container.decodeIfPresent(Bool.self, forKey: .neg)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'neg': \(error)")

                throw error
            }
            do {
                cts = try container.decode(ATProtocolDate.self, forKey: .cts)

            } catch {
                LogManager.logError("Decoding error for required property 'cts': \(error)")

                throw error
            }
            do {
                exp = try container.decodeIfPresent(ATProtocolDate.self, forKey: .exp)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'exp': \(error)")

                throw error
            }
            do {
                sig = try container.decodeIfPresent(Bytes.self, forKey: .sig)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'sig': \(error)")

                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(ver, forKey: .ver)

            try container.encode(src, forKey: .src)

            try container.encode(uri, forKey: .uri)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cid, forKey: .cid)

            try container.encode(val, forKey: .val)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(neg, forKey: .neg)

            try container.encode(cts, forKey: .cts)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(exp, forKey: .exp)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(sig, forKey: .sig)
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            if let value = ver {
                // Encode optional property even if it's an empty array for CBOR

                let verValue = try value.toCBORValue()
                map = map.adding(key: "ver", value: verValue)
            }

            let srcValue = try src.toCBORValue()
            map = map.adding(key: "src", value: srcValue)

            let uriValue = try uri.toCBORValue()
            map = map.adding(key: "uri", value: uriValue)

            if let value = cid {
                // Encode optional property even if it's an empty array for CBOR

                let cidValue = try value.toCBORValue()
                map = map.adding(key: "cid", value: cidValue)
            }

            let valValue = try val.toCBORValue()
            map = map.adding(key: "val", value: valValue)

            if let value = neg {
                // Encode optional property even if it's an empty array for CBOR

                let negValue = try value.toCBORValue()
                map = map.adding(key: "neg", value: negValue)
            }

            let ctsValue = try cts.toCBORValue()
            map = map.adding(key: "cts", value: ctsValue)

            if let value = exp {
                // Encode optional property even if it's an empty array for CBOR

                let expValue = try value.toCBORValue()
                map = map.adding(key: "exp", value: expValue)
            }

            if let value = sig {
                // Encode optional property even if it's an empty array for CBOR

                let sigValue = try value.toCBORValue()
                map = map.adding(key: "sig", value: sigValue)
            }

            return map
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
                LogManager.logError("Decoding error for required property 'values': \(error)")

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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let valuesValue = try values.toCBORValue()
            map = map.adding(key: "values", value: valuesValue)

            return map
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
                LogManager.logError("Decoding error for required property 'val': \(error)")

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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let valValue = try val.toCBORValue()
            map = map.adding(key: "val", value: valValue)

            return map
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
                LogManager.logError("Decoding error for required property 'identifier': \(error)")

                throw error
            }
            do {
                severity = try container.decode(String.self, forKey: .severity)

            } catch {
                LogManager.logError("Decoding error for required property 'severity': \(error)")

                throw error
            }
            do {
                blurs = try container.decode(String.self, forKey: .blurs)

            } catch {
                LogManager.logError("Decoding error for required property 'blurs': \(error)")

                throw error
            }
            do {
                defaultSetting = try container.decodeIfPresent(String.self, forKey: .defaultSetting)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'defaultSetting': \(error)")

                throw error
            }
            do {
                adultOnly = try container.decodeIfPresent(Bool.self, forKey: .adultOnly)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'adultOnly': \(error)")

                throw error
            }
            do {
                locales = try container.decode([LabelValueDefinitionStrings].self, forKey: .locales)

            } catch {
                LogManager.logError("Decoding error for required property 'locales': \(error)")

                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(identifier, forKey: .identifier)

            try container.encode(severity, forKey: .severity)

            try container.encode(blurs, forKey: .blurs)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(defaultSetting, forKey: .defaultSetting)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(adultOnly, forKey: .adultOnly)

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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let identifierValue = try identifier.toCBORValue()
            map = map.adding(key: "identifier", value: identifierValue)

            let severityValue = try severity.toCBORValue()
            map = map.adding(key: "severity", value: severityValue)

            let blursValue = try blurs.toCBORValue()
            map = map.adding(key: "blurs", value: blursValue)

            if let value = defaultSetting {
                // Encode optional property even if it's an empty array for CBOR

                let defaultSettingValue = try value.toCBORValue()
                map = map.adding(key: "defaultSetting", value: defaultSettingValue)
            }

            if let value = adultOnly {
                // Encode optional property even if it's an empty array for CBOR

                let adultOnlyValue = try value.toCBORValue()
                map = map.adding(key: "adultOnly", value: adultOnlyValue)
            }

            let localesValue = try locales.toCBORValue()
            map = map.adding(key: "locales", value: localesValue)

            return map
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
                LogManager.logError("Decoding error for required property 'lang': \(error)")

                throw error
            }
            do {
                name = try container.decode(String.self, forKey: .name)

            } catch {
                LogManager.logError("Decoding error for required property 'name': \(error)")

                throw error
            }
            do {
                description = try container.decode(String.self, forKey: .description)

            } catch {
                LogManager.logError("Decoding error for required property 'description': \(error)")

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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let langValue = try lang.toCBORValue()
            map = map.adding(key: "lang", value: langValue)

            let nameValue = try name.toCBORValue()
            map = map.adding(key: "name", value: nameValue)

            let descriptionValue = try description.toCBORValue()
            map = map.adding(key: "description", value: descriptionValue)

            return map
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
        public static let exclamationhide = LabelValue(rawValue: "!hide")
        //
        public static let exclamationnodashpromote = LabelValue(rawValue: "!no-promote")
        //
        public static let exclamationwarn = LabelValue(rawValue: "!warn")
        //
        public static let exclamationnodashunauthenticated = LabelValue(rawValue: "!no-unauthenticated")
        //
        public static let dmcadashviolation = LabelValue(rawValue: "dmca-violation")
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // For string-based enum types, we return the raw string value directly
            return rawValue
        }

        // Provide allCases-like functionality
        public static var predefinedValues: [LabelValue] {
            return [
                .exclamationhide,
                .exclamationnodashpromote,
                .exclamationwarn,
                .exclamationnodashunauthenticated,
                .dmcadashviolation,
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
