import Foundation

// lexicon: 1, id: com.germnetwork.declaration

public struct ComGermnetworkDeclaration: ATProtocolCodable, ATProtocolValue {
    public static let typeIdentifier = "com.germnetwork.declaration"
    public let version: String
    public let currentKey: Bytes
    public let messageMe: MessageMe?
    public let keyPackage: Bytes?
    public let continuityProofs: [Bytes]?

    public init(version: String, currentKey: Bytes, messageMe: MessageMe?, keyPackage: Bytes?, continuityProofs: [Bytes]?) {
        self.version = version
        self.currentKey = currentKey
        self.messageMe = messageMe
        self.keyPackage = keyPackage
        self.continuityProofs = continuityProofs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(String.self, forKey: .version)
        currentKey = try container.decode(Bytes.self, forKey: .currentKey)
        messageMe = try container.decodeIfPresent(MessageMe.self, forKey: .messageMe)
        keyPackage = try container.decodeIfPresent(Bytes.self, forKey: .keyPackage)
        continuityProofs = try container.decodeIfPresent([Bytes].self, forKey: .continuityProofs)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
        try container.encode(version, forKey: .version)
        try container.encode(currentKey, forKey: .currentKey)
        try container.encodeIfPresent(messageMe, forKey: .messageMe)
        try container.encodeIfPresent(keyPackage, forKey: .keyPackage)
        try container.encodeIfPresent(continuityProofs, forKey: .continuityProofs)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.isEqual(to: rhs)
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? Self else { return false }
        if version != other.version {
            return false
        }
        if currentKey != other.currentKey {
            return false
        }
        if messageMe != other.messageMe {
            return false
        }
        if keyPackage != other.keyPackage {
            return false
        }
        if continuityProofs != other.continuityProofs {
            return false
        }
        return true
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(version)
        hasher.combine(currentKey)
        if let value = messageMe {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?)
        }
        if let value = keyPackage {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?)
        }
        if let value = continuityProofs {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?)
        }
    }

    public func toCBORValue() throws -> Any {
        var map = OrderedCBORMap()
        map = map.adding(key: "$type", value: Self.typeIdentifier)
        let versionValue = try version.toCBORValue()
        map = map.adding(key: "version", value: versionValue)
        let currentKeyValue = try currentKey.toCBORValue()
        map = map.adding(key: "currentKey", value: currentKeyValue)
        if let value = messageMe {
            let messageMeValue = try value.toCBORValue()
            map = map.adding(key: "messageMe", value: messageMeValue)
        }
        if let value = keyPackage {
            let keyPackageValue = try value.toCBORValue()
            map = map.adding(key: "keyPackage", value: keyPackageValue)
        }
        if let value = continuityProofs {
            let continuityProofsValue = try value.toCBORValue()
            map = map.adding(key: "continuityProofs", value: continuityProofsValue)
        }
        return map
    }

    private enum CodingKeys: String, CodingKey {
        case typeIdentifier = "$type"
        case version
        case currentKey
        case messageMe
        case keyPackage
        case continuityProofs
    }

    public struct MessageMe: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "com.germnetwork.declaration#messageMe"
        public let messageMeUrl: URI
        public let showButtonTo: String

        public init(
            messageMeUrl: URI, showButtonTo: String
        ) {
            self.messageMeUrl = messageMeUrl
            self.showButtonTo = showButtonTo
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                messageMeUrl = try container.decode(URI.self, forKey: .messageMeUrl)
            } catch {
                LogManager.logError("Decoding error for required property 'messageMeUrl': \(error)")
                throw error
            }
            do {
                showButtonTo = try container.decode(String.self, forKey: .showButtonTo)
            } catch {
                LogManager.logError("Decoding error for required property 'showButtonTo': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(messageMeUrl, forKey: .messageMeUrl)
            try container.encode(showButtonTo, forKey: .showButtonTo)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(messageMeUrl)
            hasher.combine(showButtonTo)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if messageMeUrl != other.messageMeUrl {
                return false
            }
            if showButtonTo != other.showButtonTo {
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
            let messageMeUrlValue = try messageMeUrl.toCBORValue()
            map = map.adding(key: "messageMeUrl", value: messageMeUrlValue)
            let showButtonToValue = try showButtonTo.toCBORValue()
            map = map.adding(key: "showButtonTo", value: showButtonToValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case messageMeUrl
            case showButtonTo
        }
    }
}
