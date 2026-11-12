import Foundation

/// The NSID of the record type Lexicons are published as.
public let lexiconSchemaCollection = "com.atproto.lexicon.schema"

/// A Lexicon document: the schema file associated with one NSID.
///
/// Parse one with ``init(json:options:)`` or ``init(_:options:)``; both check
/// the document against the Lexicon version 1 rules before returning. A
/// document assembled in Swift is checked by ``validate(options:)`` and again
/// when it is added to a ``LexiconCatalog``.
public struct LexiconDoc: Sendable, Hashable {
    /// Lexicon language version. Always `1` for a valid document.
    public var lexicon: Int
    /// The NSID this document defines.
    public var id: String
    /// Optional revision counter.
    public var revision: Int64?
    /// Short overview of the Lexicon.
    public var description: String?
    /// The definitions, keyed by short name. `main` is the primary definition.
    public var defs: [String: LexiconDef]

    /// Creates a document. Call ``validate(options:)`` before relying on it.
    public init(
        lexicon: Int = 1,
        id: String,
        revision: Int64? = nil,
        description: String? = nil,
        defs: [String: LexiconDef]
    ) {
        self.lexicon = lexicon
        self.id = id
        self.revision = revision
        self.description = description
        self.defs = defs
    }

    /// The `main` definition, if the document has one.
    public var main: LexiconDef? {
        defs["main"]
    }
}

/// One schema definition: a named entry of `defs`, or a schema nested inside
/// another (an object property, array items, a request body…).
///
/// The enum has a case for each of the nineteen Lexicon types. Which types may
/// appear where is a rule of the language, checked by
/// ``LexiconDoc/validate(options:)`` rather than encoded in the Swift types.
public indirect enum LexiconDef: Sendable, Hashable {
    /// `record`: an object stored in a repository. Primary; `main` only.
    case record(LexRecord)
    /// `query`: an XRPC query (HTTP GET). Primary; `main` only.
    case query(LexXRPCQuery)
    /// `procedure`: an XRPC procedure (HTTP POST). Primary; `main` only.
    case procedure(LexXRPCProcedure)
    /// `subscription`: an event stream. Primary; `main` only.
    case subscription(LexXRPCSubscription)
    /// `permission-set`: a bundle of auth permissions. Primary; `main` only.
    case permissionSet(LexPermissionSet)
    /// `object`.
    case object(LexObject)
    /// `array`.
    case array(LexArray)
    /// `token`: a name with no data representation.
    case token(LexToken)
    /// `string`.
    case string(LexString)
    /// `integer`.
    case integer(LexInteger)
    /// `boolean`.
    case boolean(LexBoolean)
    /// `bytes`.
    case bytes(LexBytes)
    /// `cid-link`.
    case cidLink(LexCIDLink)
    /// `blob`.
    case blob(LexBlob)
    /// `unknown`: any object.
    case unknown(LexUnknown)
    /// `ref`: a reference to another definition.
    case ref(LexRef)
    /// `union`: one of several referenced definitions, discriminated by `$type`.
    case union(LexUnion)
    /// `params`: HTTP query parameters. Only valid as the `parameters` of a
    /// query, procedure or subscription.
    case params(LexParams)
    /// `permission`: one permission. Only valid inside a permission set.
    case permission(LexPermission)
    /// A definition whose `type` is not part of Lexicon version 1. Produced
    /// only when ``LexiconSchemaOptions/allowUnknownDefinitionTypes`` is set;
    /// data can never validate against it.
    case unsupported(LexUnsupportedDef)

    /// The Lexicon `type` string of this definition.
    public var typeName: String {
        switch self {
        case .record: return "record"
        case .query: return "query"
        case .procedure: return "procedure"
        case .subscription: return "subscription"
        case .permissionSet: return "permission-set"
        case .object: return "object"
        case .array: return "array"
        case .token: return "token"
        case .string: return "string"
        case .integer: return "integer"
        case .boolean: return "boolean"
        case .bytes: return "bytes"
        case .cidLink: return "cid-link"
        case .blob: return "blob"
        case .unknown: return "unknown"
        case .ref: return "ref"
        case .union: return "union"
        case .params: return "params"
        case .permission: return "permission"
        case let .unsupported(def): return def.type
        }
    }

    /// `true` for the five primary types, which may only be named `main`.
    public var isPrimary: Bool {
        switch self {
        case .record, .query, .procedure, .subscription, .permissionSet: return true
        default: return false
        }
    }

    /// The definition's `description`, if any.
    public var description: String? {
        switch self {
        case let .record(def): return def.description
        case let .query(def): return def.description
        case let .procedure(def): return def.description
        case let .subscription(def): return def.description
        case let .permissionSet(def): return def.description
        case let .object(def): return def.description
        case let .array(def): return def.description
        case let .token(def): return def.description
        case let .string(def): return def.description
        case let .integer(def): return def.description
        case let .boolean(def): return def.description
        case let .bytes(def): return def.description
        case let .cidLink(def): return def.description
        case let .blob(def): return def.description
        case let .unknown(def): return def.description
        case let .ref(def): return def.description
        case let .union(def): return def.description
        case let .params(def): return def.description
        case .permission, .unsupported: return nil
        }
    }
}

// MARK: - Primary types

/// A `record` definition.
public struct LexRecord: Sendable, Hashable {
    /// Short description.
    public var description: String?
    /// The record key type: `tid`, `nsid`, `any` or `literal:<value>`.
    public var key: String
    /// The schema of the record object.
    public var record: LexObject

    /// Creates a record definition.
    public init(description: String? = nil, key: String, record: LexObject) {
        self.description = description
        self.key = key
        self.record = record
    }

    /// ``key`` parsed into its kind, or `nil` if it is not one of the key
    /// types the record-key specification defines.
    public var keyType: LexRecordKeyType? {
        LexRecordKeyType(key)
    }
}

/// The record key types a `record` definition can declare.
public enum LexRecordKeyType: Sendable, Hashable {
    /// `tid`: the key is a TID.
    case tid
    /// `nsid`: the key is an NSID.
    case nsid
    /// `any`: any valid record key.
    case any
    /// `literal:<value>`: the key is exactly `value`.
    case literal(String)

    /// Parses the `key` string of a record definition.
    public init?(_ key: String) {
        switch key {
        case "tid": self = .tid
        case "nsid": self = .nsid
        case "any": self = .any
        default:
            guard key.hasPrefix("literal:") else { return nil }
            let value = String(key.dropFirst("literal:".count))
            guard LexSyntax.isRecordKey(value) else { return nil }
            self = .literal(value)
        }
    }

    /// Whether `recordKey` is acceptable for this key type.
    public func accepts(_ recordKey: String) -> Bool {
        guard LexSyntax.isRecordKey(recordKey) else { return false }
        switch self {
        case .tid: return LexSyntax.isTID(recordKey)
        case .nsid: return LexSyntax.isNSID(recordKey)
        case .any: return true
        case let .literal(value): return recordKey == value
        }
    }
}

/// The body of an XRPC request or response.
public struct LexXRPCBody: Sendable, Hashable {
    /// Short description.
    public var description: String?
    /// MIME type of the body, for example `application/json`.
    public var encoding: String
    /// Schema of a JSON body: an `object`, a `ref` or a `union`.
    public var schema: LexiconDef?

    /// Creates a body description.
    public init(description: String? = nil, encoding: String, schema: LexiconDef? = nil) {
        self.description = description
        self.encoding = encoding
        self.schema = schema
    }
}

/// A named error an XRPC endpoint may return.
public struct LexXRPCError: Sendable, Hashable {
    /// The error name, with no whitespace.
    public var name: String
    /// Short description.
    public var description: String?

    /// Creates an error declaration.
    public init(name: String, description: String? = nil) {
        self.name = name
        self.description = description
    }
}

/// A `query` definition.
public struct LexXRPCQuery: Sendable, Hashable {
    /// Short description.
    public var description: String?
    /// HTTP query parameters.
    public var parameters: LexParams?
    /// Response body.
    public var output: LexXRPCBody?
    /// Declared errors.
    public var errors: [LexXRPCError]?

    /// Creates a query definition.
    public init(
        description: String? = nil,
        parameters: LexParams? = nil,
        output: LexXRPCBody? = nil,
        errors: [LexXRPCError]? = nil
    ) {
        self.description = description
        self.parameters = parameters
        self.output = output
        self.errors = errors
    }
}

/// A `procedure` definition.
public struct LexXRPCProcedure: Sendable, Hashable {
    /// Short description.
    public var description: String?
    /// HTTP query parameters.
    public var parameters: LexParams?
    /// Request body.
    public var input: LexXRPCBody?
    /// Response body.
    public var output: LexXRPCBody?
    /// Declared errors.
    public var errors: [LexXRPCError]?

    /// Creates a procedure definition.
    public init(
        description: String? = nil,
        parameters: LexParams? = nil,
        input: LexXRPCBody? = nil,
        output: LexXRPCBody? = nil,
        errors: [LexXRPCError]? = nil
    ) {
        self.description = description
        self.parameters = parameters
        self.input = input
        self.output = output
        self.errors = errors
    }
}

/// The message description of a subscription.
public struct LexXRPCMessage: Sendable, Hashable {
    /// Short description.
    public var description: String?
    /// The message schema, which must be a `union`.
    public var schema: LexiconDef

    /// Creates a message description.
    public init(description: String? = nil, schema: LexiconDef) {
        self.description = description
        self.schema = schema
    }
}

/// A `subscription` definition.
public struct LexXRPCSubscription: Sendable, Hashable {
    /// Short description.
    public var description: String?
    /// HTTP query parameters of the upgrade request.
    public var parameters: LexParams?
    /// The messages the stream carries.
    public var message: LexXRPCMessage
    /// Declared errors.
    public var errors: [LexXRPCError]?

    /// Creates a subscription definition.
    public init(
        description: String? = nil,
        parameters: LexParams? = nil,
        message: LexXRPCMessage,
        errors: [LexXRPCError]? = nil
    ) {
        self.description = description
        self.parameters = parameters
        self.message = message
        self.errors = errors
    }
}

/// A `permission-set` definition.
public struct LexPermissionSet: Sendable, Hashable {
    /// Short description.
    public var description: String?
    /// Short display name.
    public var title: String?
    /// Localised titles, keyed by language tag (`title:lang`).
    public var titleLang: [String: String]?
    /// Longer display text.
    public var detail: String?
    /// Localised details, keyed by language tag (`detail:lang`).
    public var detailLang: [String: String]?
    /// The permissions in the set.
    public var permissions: [LexPermission]

    /// Creates a permission-set definition.
    public init(
        description: String? = nil,
        title: String? = nil,
        titleLang: [String: String]? = nil,
        detail: String? = nil,
        detailLang: [String: String]? = nil,
        permissions: [LexPermission]
    ) {
        self.description = description
        self.title = title
        self.titleLang = titleLang
        self.detail = detail
        self.detailLang = detailLang
        self.permissions = permissions
    }
}

public extension LexPermissionSet {
    /// The grants this set makes when it is published under `nsid`.
    ///
    /// Two filters apply, both required of anything that turns a permission
    /// set into access:
    /// - a declaration that must be ignored (see ``LexPermission/grant``) is
    ///   dropped;
    /// - a declaration is dropped as a whole unless every collection or
    ///   endpoint it names is under the set's own namespace (see
    ///   ``covers(_:publishedAs:)``), so a set can not grant access to
    ///   another authority's resources.
    func grants(publishedAs nsid: String) -> [LexPermission.Grant] {
        permissions.compactMap { permission in
            guard let grant = permission.grant else { return nil }
            let named: [String]
            switch grant {
            case let .repo(collections, _): named = collections
            case let .rpc(methods, _): named = methods
            }
            return named.allSatisfy { LexPermissionSet.covers($0, publishedAs: nsid) } ? grant : nil
        }
    }

    /// Whether a permission set published as `setNSID` has namespace
    /// authority over `resourceNSID`.
    ///
    /// A set may address resources in its own NSID group (the NSID minus its
    /// name) and in child groups, recursively, but not in sibling or parent
    /// groups: `app.example.feed.authPost` covers `app.example.feed.post` and
    /// `app.example.feed.thread.getReplies`, and does not cover
    /// `app.example.actor.profile` or `app.example.profile`.
    static func covers(_ resourceNSID: String, publishedAs setNSID: String) -> Bool {
        guard LexSyntax.isNSID(setNSID), LexSyntax.isNSID(resourceNSID),
              let lastDot = setNSID.lastIndex(of: ".")
        else {
            return false
        }
        // The group, including its trailing dot: "app.example.feed."
        return resourceNSID.hasPrefix(setNSID[...lastDot])
    }
}

/// A `permission` declaration inside a permission set.
///
/// The set of resources and their parameters is expected to grow, so the
/// declaration is kept as written: ``resource`` plus the raw ``parameters``.
/// ``grant`` interprets it under the rules that apply inside a permission set
/// and returns `nil` for anything a service must ignore.
public struct LexPermission: Sendable, Hashable {
    /// The resource type: `repo`, `rpc`, or any other (possibly future) name.
    public var resource: String
    /// Every other field of the declaration, as written.
    public var parameters: [String: LexValue]

    /// Creates a permission declaration.
    public init(resource: String, parameters: [String: LexValue] = [:]) {
        self.resource = resource
        self.parameters = parameters
    }

    /// What a permission grants once interpreted.
    public enum Grant: Sendable, Hashable {
        /// Write access to records of the listed collections. `actions` is
        /// `nil` when the declaration does not limit the operations.
        case repo(collections: [String], actions: [String]?)
        /// Remote API calls to the listed endpoints, either against any
        /// audience (`aud: "*"`) or the audience inherited from the including
        /// scope (`inheritAud: true`).
        case rpc(methods: [String], inheritAudience: Bool)
    }

    /// The grant this declaration makes, or `nil` when it must be ignored.
    ///
    /// Per the Lexicon and permission specifications a declaration is ignored
    /// when its resource is not `repo` or `rpc` (`blob`, `account` and
    /// `identity` are not supported in a permission set), when it carries a
    /// parameter this implementation does not know, or when a parameter is
    /// malformed: an empty or wildcard `collection` / `lxm`, a duplicate
    /// entry, an action other than `create` / `update` / `delete`, an `aud`
    /// other than `*`, or `aud` together with `inheritAud`.
    public var grant: Grant? {
        func uniqueStrings(_ value: LexValue?) -> [String]? {
            guard let items = value?.arrayValue else { return nil }
            let strings = items.compactMap(\.stringValue)
            guard strings.count == items.count, Set(strings).count == strings.count else { return nil }
            return strings
        }
        switch resource {
        case "repo":
            guard Set(parameters.keys).isSubset(of: ["collection", "action"]) else { return nil }
            guard let collections = uniqueStrings(parameters["collection"]), !collections.isEmpty,
                  collections.allSatisfy(LexSyntax.isNSID)
            else {
                return nil
            }
            var actions: [String]?
            if parameters["action"] != nil {
                guard let listed = uniqueStrings(parameters["action"]),
                      listed.allSatisfy({ ["create", "update", "delete"].contains($0) })
                else {
                    return nil
                }
                actions = listed
            }
            return .repo(collections: collections, actions: actions)
        case "rpc":
            guard Set(parameters.keys).isSubset(of: ["lxm", "aud", "inheritAud"]) else { return nil }
            guard let methods = uniqueStrings(parameters["lxm"]), !methods.isEmpty,
                  methods.allSatisfy(LexSyntax.isNSID)
            else {
                return nil
            }
            var inherit = false
            if let flag = parameters["inheritAud"] {
                guard let value = flag.boolValue else { return nil }
                inherit = value
            }
            if let audience = parameters["aud"] {
                guard !inherit, audience.stringValue == "*" else { return nil }
                return .rpc(methods: methods, inheritAudience: false)
            }
            return inherit ? .rpc(methods: methods, inheritAudience: true) : nil
        default:
            return nil
        }
    }
}

// MARK: - Field types

/// An `object` definition.
public struct LexObject: Sendable, Hashable {
    /// Short description.
    public var description: String?
    /// The properties, by name.
    public var properties: [String: LexiconDef]
    /// Names of the properties that must be present.
    public var required: [String]?
    /// Names of the properties that may be `null`.
    public var nullable: [String]?

    /// Creates an object definition.
    public init(
        description: String? = nil,
        properties: [String: LexiconDef] = [:],
        required: [String]? = nil,
        nullable: [String]? = nil
    ) {
        self.description = description
        self.properties = properties
        self.required = required
        self.nullable = nullable
    }
}

/// A `params` definition: the HTTP query parameters of an endpoint.
public struct LexParams: Sendable, Hashable {
    /// Short description.
    public var description: String?
    /// The parameters, by name. Each is a `boolean`, `integer`, `string` or
    /// `unknown`, or an `array` of one of those.
    public var properties: [String: LexiconDef]
    /// Names of the parameters that must be present.
    public var required: [String]?

    /// Creates a params definition.
    public init(description: String? = nil, properties: [String: LexiconDef] = [:], required: [String]? = nil) {
        self.description = description
        self.properties = properties
        self.required = required
    }
}

/// An `array` definition.
public struct LexArray: Sendable, Hashable {
    /// Short description.
    public var description: String?
    /// Schema of the elements.
    public var items: LexiconDef
    /// Minimum number of elements.
    public var minLength: Int?
    /// Maximum number of elements.
    public var maxLength: Int?

    /// Creates an array definition.
    public init(description: String? = nil, items: LexiconDef, minLength: Int? = nil, maxLength: Int? = nil) {
        self.description = description
        self.items = items
        self.minLength = minLength
        self.maxLength = maxLength
    }
}

/// A `token` definition.
public struct LexToken: Sendable, Hashable {
    /// Short description, which carries the token's meaning.
    public var description: String?

    /// Creates a token definition.
    public init(description: String? = nil) {
        self.description = description
    }
}

/// A `string` definition.
public struct LexString: Sendable, Hashable {
    /// Short description.
    public var description: String?
    /// Format restriction.
    public var format: LexStringFormat?
    /// Minimum length in UTF-8 bytes.
    public var minLength: Int?
    /// Maximum length in UTF-8 bytes.
    public var maxLength: Int?
    /// Minimum length in grapheme clusters.
    public var minGraphemes: Int?
    /// Maximum length in grapheme clusters.
    public var maxGraphemes: Int?
    /// Suggested values. Never restricts the value.
    public var knownValues: [String]?
    /// The closed set of allowed values.
    public var enumValues: [String]?
    /// Default value.
    public var defaultValue: String?
    /// The single allowed value.
    public var constValue: String?

    /// Creates a string definition.
    public init(
        description: String? = nil,
        format: LexStringFormat? = nil,
        minLength: Int? = nil,
        maxLength: Int? = nil,
        minGraphemes: Int? = nil,
        maxGraphemes: Int? = nil,
        knownValues: [String]? = nil,
        enumValues: [String]? = nil,
        defaultValue: String? = nil,
        constValue: String? = nil
    ) {
        self.description = description
        self.format = format
        self.minLength = minLength
        self.maxLength = maxLength
        self.minGraphemes = minGraphemes
        self.maxGraphemes = maxGraphemes
        self.knownValues = knownValues
        self.enumValues = enumValues
        self.defaultValue = defaultValue
        self.constValue = constValue
    }
}

/// An `integer` definition.
public struct LexInteger: Sendable, Hashable {
    /// Short description.
    public var description: String?
    /// Minimum acceptable value.
    public var minimum: Int64?
    /// Maximum acceptable value.
    public var maximum: Int64?
    /// The closed set of allowed values.
    public var enumValues: [Int64]?
    /// Default value.
    public var defaultValue: Int64?
    /// The single allowed value.
    public var constValue: Int64?

    /// Creates an integer definition.
    public init(
        description: String? = nil,
        minimum: Int64? = nil,
        maximum: Int64? = nil,
        enumValues: [Int64]? = nil,
        defaultValue: Int64? = nil,
        constValue: Int64? = nil
    ) {
        self.description = description
        self.minimum = minimum
        self.maximum = maximum
        self.enumValues = enumValues
        self.defaultValue = defaultValue
        self.constValue = constValue
    }
}

/// A `boolean` definition.
public struct LexBoolean: Sendable, Hashable {
    /// Short description.
    public var description: String?
    /// Default value.
    public var defaultValue: Bool?
    /// The single allowed value.
    public var constValue: Bool?

    /// Creates a boolean definition.
    public init(description: String? = nil, defaultValue: Bool? = nil, constValue: Bool? = nil) {
        self.description = description
        self.defaultValue = defaultValue
        self.constValue = constValue
    }
}

/// A `bytes` definition.
public struct LexBytes: Sendable, Hashable {
    /// Short description.
    public var description: String?
    /// Minimum size in bytes.
    public var minLength: Int?
    /// Maximum size in bytes.
    public var maxLength: Int?

    /// Creates a bytes definition.
    public init(description: String? = nil, minLength: Int? = nil, maxLength: Int? = nil) {
        self.description = description
        self.minLength = minLength
        self.maxLength = maxLength
    }
}

/// A `cid-link` definition.
public struct LexCIDLink: Sendable, Hashable {
    /// Short description.
    public var description: String?

    /// Creates a cid-link definition.
    public init(description: String? = nil) {
        self.description = description
    }
}

/// A `blob` definition.
public struct LexBlob: Sendable, Hashable {
    /// Short description.
    public var description: String?
    /// Acceptable MIME types. An entry may be `type/subtype`, `type/*`, or
    /// `*/*`.
    public var accept: [String]?
    /// Maximum size in bytes.
    public var maxSize: Int64?

    /// Creates a blob definition.
    public init(description: String? = nil, accept: [String]? = nil, maxSize: Int64? = nil) {
        self.description = description
        self.accept = accept
        self.maxSize = maxSize
    }

    /// Whether `mimeType` matches one of the ``accept`` patterns. Everything
    /// is accepted when ``accept`` is `nil`.
    public func accepts(mimeType: String) -> Bool {
        guard let accept else { return true }
        return accept.contains { LexBlob.pattern($0, matches: mimeType) }
    }

    /// Whether `pattern` is a well-formed `accept` entry: `type/subtype`,
    /// `type/*` or `*/*`. A bare `*` and partial globs such as `text/ht*` are
    /// not supported by the specification.
    public static func isValidAcceptPattern(_ pattern: String) -> Bool {
        let parts = pattern.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return false }
        if pattern == "*/*" {
            return true
        }
        func isToken(_ part: Substring) -> Bool {
            part.utf8.allSatisfy { $0 > 0x20 && $0 < 0x7F && $0 != UInt8(ascii: "*") && $0 != UInt8(ascii: ";") && $0 != UInt8(ascii: ",") }
        }
        guard isToken(parts[0]) else { return false }
        return parts[1] == "*" || isToken(parts[1])
    }

    static func pattern(_ pattern: String, matches mimeType: String) -> Bool {
        if pattern == "*/*" {
            return true
        }
        // MIME types are case-insensitive; parameters ("; charset=…") are not
        // part of the type being matched.
        let bare = mimeType.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? mimeType
        let candidate = bare.trimmingCharacters(in: .whitespaces).lowercased()
        let wanted = pattern.lowercased()
        if wanted.hasSuffix("/*") {
            return candidate.hasPrefix(wanted.dropLast())
        }
        return candidate == wanted
    }
}

/// An `unknown` definition.
public struct LexUnknown: Sendable, Hashable {
    /// Short description.
    public var description: String?

    /// Creates an unknown definition.
    public init(description: String? = nil) {
        self.description = description
    }
}

/// A `ref` definition.
public struct LexRef: Sendable, Hashable {
    /// Short description.
    public var description: String?
    /// The reference: `nsid`, `nsid#name`, or `#name` for a definition in the
    /// same document.
    public var ref: String

    /// Creates a ref definition.
    public init(description: String? = nil, ref: String) {
        self.description = description
        self.ref = ref
    }
}

/// A `union` definition.
public struct LexUnion: Sendable, Hashable {
    /// Short description.
    public var description: String?
    /// References to the variants.
    public var refs: [String]
    /// `true` when the set of variants is fixed. `nil` means open.
    public var closed: Bool?

    /// Creates a union definition.
    public init(description: String? = nil, refs: [String], closed: Bool? = nil) {
        self.description = description
        self.refs = refs
        self.closed = closed
    }

    /// Whether the union is closed.
    public var isClosed: Bool {
        closed ?? false
    }
}

/// A definition of a type outside Lexicon version 1, kept verbatim.
public struct LexUnsupportedDef: Sendable, Hashable {
    /// The unrecognised `type` string.
    public var type: String
    /// The definition as written.
    public var raw: LexValue

    /// Creates an unsupported definition.
    public init(type: String, raw: LexValue) {
        self.type = type
        self.raw = raw
    }
}
