import Foundation

// lexicon: 1, id: app.bsky.graph.verification

public struct AppBskyGraphVerification: ATProtocolCodable, ATProtocolValue {
    public static let typeIdentifier = "app.bsky.graph.verification"
    public let subject: DID
    public let handle: Handle
    public let displayName: String
    public let createdAt: ATProtocolDate

    public init(subject: DID, handle: Handle, displayName: String, createdAt: ATProtocolDate) {
        self.subject = subject
        self.handle = handle
        self.displayName = displayName
        self.createdAt = createdAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        subject = try container.decode(DID.self, forKey: .subject)
        handle = try container.decode(Handle.self, forKey: .handle)
        displayName = try container.decode(String.self, forKey: .displayName)
        createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
        try container.encode(subject, forKey: .subject)
        try container.encode(handle, forKey: .handle)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(createdAt, forKey: .createdAt)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.isEqual(to: rhs)
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? Self else { return false }
        if subject != other.subject {
            return false
        }
        if handle != other.handle {
            return false
        }
        if displayName != other.displayName {
            return false
        }
        if createdAt != other.createdAt {
            return false
        }
        return true
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(subject)
        hasher.combine(handle)
        hasher.combine(displayName)
        hasher.combine(createdAt)
    }

    public func toCBORValue() throws -> Any {
        var map = OrderedCBORMap()
        map = map.adding(key: "$type", value: Self.typeIdentifier)
        let subjectValue = try subject.toCBORValue()
        map = map.adding(key: "subject", value: subjectValue)
        let handleValue = try handle.toCBORValue()
        map = map.adding(key: "handle", value: handleValue)
        let displayNameValue = try displayName.toCBORValue()
        map = map.adding(key: "displayName", value: displayNameValue)
        let createdAtValue = try createdAt.toCBORValue()
        map = map.adding(key: "createdAt", value: createdAtValue)
        return map
    }

    private enum CodingKeys: String, CodingKey {
        case typeIdentifier = "$type"
        case subject
        case handle
        case displayName
        case createdAt
    }
}
