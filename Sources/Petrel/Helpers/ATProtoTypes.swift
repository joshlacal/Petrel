//
//  ATProtoTypes.swift
//
//
//  Created by Josh LaCalamito on 11/30/23.
//

import Foundation

public protocol ATProtocolCodable: Codable, Sendable {}

public protocol ATProtocolValue: ATProtocolCodable, Equatable, Hashable {
    func isEqual(to other: any ATProtocolValue) -> Bool
}

public enum ATProtocolError: Error {
    case invalidURI(String)
}

// MARK: URIs

public struct ATProtocolURI: ATProtocolValue, CustomStringConvertible, QueryParameterConvertible {
    public let authority: String
    public let collection: String?
    public let recordKey: String?

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let uriString = try container.decode(String.self)

        try self.init(uriString: uriString)
    }

    public init(uriString: String) throws {
        guard uriString.hasPrefix("at://"),
              uriString.utf8.count <= 8192
        else {
            throw ATProtocolError.invalidURI("Invalid AT URI format or length")
        }

        let trimmedString = String(uriString.dropFirst(5)) // Remove "at://"
        let components = trimmedString.components(separatedBy: "/").filter { !$0.isEmpty }

        guard let authorityComponent = components.first,
              !authorityComponent.isEmpty
        else {
            throw ATProtocolError.invalidURI("Invalid AT URI: missing or empty authority")
        }

        authority = authorityComponent
        collection = components.count > 1 ? components[1] : nil
        recordKey = components.count > 2 ? components[2] : nil
    }

    public var description: String {
        return uriString()
    }

    public func uriString() -> String {
        var uri = "at://\(authority)"
        if let collection = collection {
            uri += "/\(collection)"
        }
        if let recordKey = recordKey {
            uri += "/\(recordKey)"
        }
        return uri
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherURI = other as? ATProtocolURI else {
            return false
        }

        return authority == otherURI.authority && collection == otherURI.collection
            && recordKey == otherURI.recordKey
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let uriString = self.uriString()
        try container.encode(uriString)
    }

    func asQueryItem(name: String) -> URLQueryItem? {
        return URLQueryItem(name: name, value: uriString())
    }
}

public struct URI: ATProtocolValue, CustomStringConvertible, QueryParameterConvertible,
    ExpressibleByStringLiteral
{
    public let scheme: String
    public let authority: String
    public let path: String?
    public let query: String?
    public let fragment: String?
    public let isDID: Bool

    enum URIError: Error {
        case invalidScheme
        case invalidURI
        case invalidDID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let uriString = try container.decode(String.self)

        if uriString.starts(with: "did:") {
            isDID = true
            let components = uriString.split(separator: ":")
            guard components.count >= 3 else {
                throw URIError.invalidDID
            }
            scheme = String(components[0])
            authority = String(components[1])
            path = components.dropFirst(2).joined(separator: ":")
            query = nil
            fragment = nil
        } else {
            isDID = false
            let urlComponents = URLComponents(string: uriString)
            scheme = urlComponents?.scheme ?? ""
            authority = urlComponents?.host ?? ""
            path = urlComponents?.path.isEmpty ?? true ? nil : urlComponents?.path
            query = urlComponents?.query
            fragment = urlComponents?.fragment
        }
    }

    init(uriString: String) {
        if uriString.starts(with: "did:") {
            isDID = true
            let components = uriString.split(separator: ":")
            scheme = "did"
            authority = String(components[1])
            path = components.count > 2 ? components.dropFirst(2).joined(separator: ":") : nil
            query = nil
            fragment = nil
        } else {
            isDID = false
            let urlComponents = URLComponents(string: uriString)
            let defaultScheme = "https"
            scheme = urlComponents?.scheme ?? defaultScheme
            authority = urlComponents?.host ?? ""
            path = urlComponents?.path.isEmpty ?? true ? nil : urlComponents?.path
            query = urlComponents?.query
            fragment = urlComponents?.fragment
        }
    }

    func isValid() -> Bool {
        if isDID {
            return scheme == "did" && !authority.isEmpty
        } else {
            return !scheme.isEmpty && !authority.isEmpty
        }
    }

    func asQueryItem(name: String) -> URLQueryItem? {
        guard isValid() else {
            return nil
        }
        return URLQueryItem(name: name, value: uriString())
    }

    public func uriString() -> String {
        if isDID {
            var didString = "did:\(authority)"
            if let path = path {
                didString += ":\(path)"
            }
            return didString
        } else {
            var components = URLComponents()
            components.scheme = scheme.isEmpty ? nil : scheme
            components.host = authority
            components.path = path ?? ""
            components.query = query
            components.fragment = fragment
            return components.string ?? "invalid-uri"
        }
    }
    
    // Initializer to create URI from URL
    public init(url: URL) {
        self.isDID = false
        self.scheme = url.scheme ?? "https"
        self.authority = url.host ?? ""
        self.path = url.path.isEmpty ? nil : url.path
        self.query = url.query
        self.fragment = url.fragment
    }

    // Computed property to get URL from URI
    public var url: URL? {
        guard !isDID else { return nil }
        var components = URLComponents()
        components.scheme = scheme.isEmpty ? nil : scheme
        components.host = authority
        components.path = path ?? ""
        components.query = query
        components.fragment = fragment
        return components.url
    }


    public init(stringLiteral value: String) {
        self.init(uriString: value)
    }

    public init?(_ description: String) {
        self.init(uriString: description)
    }

    public var description: String {
        return uriString()
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherURI = other as? URI else {
            return false
        }
        return scheme == otherURI.scheme && authority == otherURI.authority && path == otherURI.path
            && query == otherURI.query && fragment == otherURI.fragment && isDID == otherURI.isDID
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let uriString = self.uriString()
        try container.encode(uriString)
    }
}

// MARK: Blob

public struct Blob: Codable, ATProtocolCodable, Hashable, Equatable, Sendable {
    public let type: String
    public let ref: ATProtoLink?
    public let mimeType: String
    public let size: Int
    public let cid: String?

    enum CodingKeys: String, CodingKey {
        case type = "$type"
        case ref
        case mimeType
        case size
        case cid
    }

    public init(
        type: String, ref: ATProtoLink? = nil, mimeType: String, size: Int, cid: String? = nil
    ) {
        self.type = type
        self.ref = ref
        self.mimeType = mimeType
        self.size = size
        self.cid = cid
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        ref = try container.decodeIfPresent(ATProtoLink.self, forKey: .ref)
        mimeType = try container.decode(String.self, forKey: .mimeType)
        size = try container.decode(Int.self, forKey: .size)
        cid = try container.decodeIfPresent(String.self, forKey: .cid)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(ref, forKey: .ref)
        try container.encode(mimeType, forKey: .mimeType)
        try container.encode(size, forKey: .size)
        try container.encodeIfPresent(cid, forKey: .cid)
    }

    public func isEqual(to other: any ATProtocolCodable) -> Bool {
        guard let otherBlob = other as? Blob else { return false }
        return self == otherBlob
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(ref)
        hasher.combine(mimeType)
        hasher.combine(size)
        hasher.combine(cid)
    }
}

// MARK: $link

public struct ATProtoLink: Codable, ATProtocolCodable, Hashable, Equatable, Sendable {
    public let cid: String

    enum CodingKeys: String, CodingKey {
        case cid = "$link"
    }

    public init(cid: String) {
        self.cid = cid
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cid = try container.decode(String.self, forKey: .cid)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(cid, forKey: .cid)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(cid)
    }

    public func isEqual(to other: any ATProtocolCodable) -> Bool {
        guard let otherLink = other as? ATProtoLink else { return false }
        return self == otherLink
    }
}

// MARK: $bytes

public struct Bytes: Codable, ATProtocolCodable, Hashable, Equatable, Sendable {
    public let data: Data

    enum CodingKeys: String, CodingKey {
        case data = "$bytes"
    }

    public init(data: Data) {
        self.data = data
    }

    public init?(string: String) {
        guard let data = string.data(using: .utf8) else {
            return nil
        }
        self.data = data
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let base64String = try container.decode(String.self, forKey: .data)
        guard let data = Data(base64Encoded: base64String) else {
            throw DecodingError.dataCorruptedError(
                forKey: .data,
                in: container,
                debugDescription: "Base64 string could not be decoded"
            )
        }
        self.data = data
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let base64String = data.base64EncodedString()
        try container.encode(base64String, forKey: .data)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(data)
    }

    public func isEqual(to other: any ATProtocolCodable) -> Bool {
        guard let otherBytes = other as? Bytes else { return false }
        return self == otherBytes
    }
}

extension AppBskyFeedDefs.FeedViewPost: Identifiable {
    public var id: String {
        if case let .appBskyFeedDefsReasonRepost(reasonRepost) = reason {
            let reposterDID = reasonRepost.by.did
            return "\(post.uri)-repostedBy-\(reposterDID)"
        } else if let replyRef = reply {
            let rootId = extractIdentifierFrom(replyRef.root)
            let parentId = extractIdentifierFrom(replyRef.parent)
            return "\(post.uri)-reply-root-\(rootId)-parent-\(parentId)"
        } else {
            return post.uri.uriString()
        }
    }

    private func extractIdentifierFrom(_ union: AppBskyFeedDefs.ReplyRefRootUnion) -> String {
        switch union {
        case let .appBskyFeedDefsPostView(postView):
            return postView.uri.uriString()
        case let .appBskyFeedDefsNotFoundPost(notFoundPost):
            return notFoundPost.uri.uriString()
        case let .appBskyFeedDefsBlockedPost(blockedPost):
            return blockedPost.uri.uriString()
        case let .unexpected(ATProtocolValueContainer):
            return ATProtocolValueContainer.hashValue.description
        }
    }

    private func extractIdentifierFrom(_ union: AppBskyFeedDefs.ReplyRefParentUnion) -> String {
        switch union {
        case let .appBskyFeedDefsPostView(postView):
            return postView.uri.uriString()
        case let .appBskyFeedDefsNotFoundPost(notFoundPost):
            return notFoundPost.uri.uriString()
        case let .appBskyFeedDefsBlockedPost(blockedPost):
            return blockedPost.uri.uriString()
        case let .unexpected(ATProtocolValueContainer):
            return ATProtocolValueContainer.hashValue.description
        }
    }
}

/*
 extension ATProtocolValueContainer: Equatable {
     public static func == (lhs: ATProtocolValueContainer, rhs: ATProtocolValueContainer) -> Bool {
         switch (lhs, rhs) {
         case (.knownType(let lhsValue), .knownType(let rhsValue)):
             return lhsValue.isEqual(to: rhsValue)
         case (.string(let lhsValue), .string(let rhsValue)):
             return lhsValue == rhsValue
         case (.number(let lhsValue), .number(let rhsValue)):
             return lhsValue == rhsValue
         case (.bigNumber(let lhsValue), .bigNumber(let rhsValue)):
             return lhsValue == rhsValue
         case (.object(let lhsValue), .object(let rhsValue)):
             return lhsValue == rhsValue
         case (.array(let lhsValue), .array(let rhsValue)):
             return lhsValue == rhsValue
         case (.bool(let lhsValue), .bool(let rhsValue)):
             return lhsValue == rhsValue
         case (.null, .null):
             return true
         case (.link(let lhsValue), .link(let rhsValue)):
             return lhsValue == rhsValue
         case (.bytes(let lhsValue), .bytes(let rhsValue)):
             return lhsValue == rhsValue
         case (.unknownType(let lhsType, let lhsValue), .unknownType(let rhsType, let rhsValue)):
             return lhsType == rhsType && lhsValue == rhsValue
         case (.decodeError(let lhsError), .decodeError(let rhsError)):
             return lhsError == rhsError
         default:
             return false
         }
     }
 }

 public extension ATProtocolValueContainer {
     func isEqual(to other: any ATProtocolValue) -> Bool {
         guard let otherValue = other as? ATProtocolValueContainer else { return false }

         switch (self, otherValue) {
         case (.knownType(let lhsValue), .knownType(let rhsValue)):
             return lhsValue.isEqual(to: rhsValue)
         case (.string(let lhsValue), .string(let rhsValue)):
             return lhsValue == rhsValue
         case (.number(let lhsValue), .number(let rhsValue)):
             return lhsValue == rhsValue
         case (.bigNumber(let lhsValue), .bigNumber(let rhsValue)):
             return lhsValue == rhsValue
         case (.object(let lhsValue), .object(let rhsValue)):
             return lhsValue == rhsValue
         case (.array(let lhsValue), .array(let rhsValue)):
             return lhsValue == rhsValue
         case (.bool(let lhsValue), .bool(let rhsValue)):
             return lhsValue == rhsValue
         case (.null, .null):
             return true
         case (.link(let lhsValue), .link(let rhsValue)):
             return lhsValue == rhsValue
         case (.bytes(let lhsValue), .bytes(let rhsValue)):
             return lhsValue == rhsValue
         case (.unknownType(let lhsType, let lhsValue), .unknownType(let rhsType, let rhsValue)):
             return lhsType == rhsType && lhsValue == rhsValue
         case (.decodeError(let lhsError), .decodeError(let rhsError)):
             return lhsError == rhsError
         default:
             return false
         }
     }
 }

 extension ATProtocolValueContainer: Hashable {
     public func hash(into hasher: inout Hasher) {
         switch self {
         case .knownType(let customValue):
             customValue.hash(into: &hasher)
         case .string(let stringValue):
             hasher.combine("string")
             hasher.combine(stringValue)
         case .number(let intValue):
             hasher.combine("number")
             hasher.combine(intValue)
         case .bigNumber(let bigNumberString):
             hasher.combine("bigNumber")
             hasher.combine(bigNumberString)
         case .object(let objectValue):
             hasher.combine("object")
             hasher.combine(objectValue)
         case .array(let arrayValue):
             hasher.combine("array")
             hasher.combine(arrayValue)
         case .bool(let boolValue):
             hasher.combine("bool")
             hasher.combine(boolValue)
         case .null:
             hasher.combine("null")
         case .link(let linkValue):
             hasher.combine("link")
             hasher.combine(linkValue)
         case .bytes(let bytesValue):
             hasher.combine("bytes")
             hasher.combine(bytesValue)
         case .unknownType(let type, let value):
             hasher.combine("unknownType")
             hasher.combine(type)
             hasher.combine(value)
         case .decodeError(let errorMessage):
             hasher.combine("decodeError")
             hasher.combine(errorMessage)
         }
     }
 }
  */
