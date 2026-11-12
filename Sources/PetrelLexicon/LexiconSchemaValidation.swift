import Foundation

/// A parsed reference to a Lexicon definition: `nsid`, `nsid#name`, or (when a
/// base document is known) `#name`.
public struct LexiconReference: Sendable, Hashable, CustomStringConvertible {
    /// The NSID of the document that holds the definition.
    public let nsid: String
    /// The definition name. `main` when the reference has no fragment.
    public let name: String

    /// Creates a reference from its parts.
    public init(nsid: String, name: String = "main") {
        self.nsid = nsid
        self.name = name
    }

    /// Parses a reference string.
    ///
    /// - Parameters:
    ///   - string: `nsid`, `nsid#name` or `#name`.
    ///   - base: The NSID of the containing document, needed to resolve a
    ///     `#name` reference.
    /// - Returns: `nil` if the string is not a syntactically valid reference,
    ///   or is local and no `base` was given.
    public init?(_ string: String, relativeTo base: String? = nil) {
        let parts = string.split(separator: "#", omittingEmptySubsequences: false)
        switch parts.count {
        case 1:
            guard LexSyntax.isNSID(string) else { return nil }
            self.init(nsid: string)
        case 2:
            let fragment = String(parts[1])
            guard LexiconReference.isValidDefinitionName(fragment) else { return nil }
            if parts[0].isEmpty {
                guard let base else { return nil }
                self.init(nsid: base, name: fragment)
            } else {
                guard LexSyntax.isNSID(String(parts[0])) else { return nil }
                self.init(nsid: String(parts[0]), name: fragment)
            }
        default:
            return nil
        }
    }

    /// The canonical spelling: the bare NSID for `main`, `nsid#name` otherwise.
    /// This is the form a `$type` field must use.
    public var description: String {
        name == "main" ? nsid : "\(nsid)#\(name)"
    }

    /// Whether `name` can be the key of a definition and so the fragment of a
    /// reference: an ASCII letter followed by ASCII letters, digits, `_` or
    /// `-`.
    public static func isValidDefinitionName(_ name: String) -> Bool {
        let bytes = Array(name.utf8)
        guard let first = bytes.first, (first >= 0x41 && first <= 0x5A) || (first >= 0x61 && first <= 0x7A) else {
            return false
        }
        return bytes.allSatisfy { byte in
            (byte >= 0x41 && byte <= 0x5A) || (byte >= 0x61 && byte <= 0x7A) || (byte >= 0x30 && byte <= 0x39)
                || byte == UInt8(ascii: "_") || byte == UInt8(ascii: "-")
        }
    }
}

public extension LexiconDoc {
    /// Checks the document against the rules of Lexicon version 1.
    ///
    /// Beyond field shapes this enforces: `lexicon` is 1; `id` is an NSID; at
    /// least one definition; primary types only as `main`; `ref`, `union`,
    /// `unknown`, `params` and `permission` never as named definitions; the
    /// types allowed in object properties, array items, query parameters and
    /// bodies; `required` / `nullable` naming defined properties; reference
    /// syntax, and for references into this document the existence and type
    /// of the target; no empty closed union; coherent constraints
    /// (non-negative lengths, minimum ≤ maximum, `const` exclusive with
    /// `default`, `default` / `const` satisfying the definition's own limits);
    /// known string formats; well-formed blob `accept` patterns and record
    /// `key` types.
    ///
    /// - Throws: ``LexiconSchemaError`` describing the first violation.
    func validate(options: LexiconSchemaOptions = .strict) throws {
        do {
            try LexiconSchemaValidator(doc: self, options: options).validate()
        } catch let error as LexiconSchemaError {
            throw error.with(nsid: id)
        }
    }
}

struct LexiconSchemaValidator {
    static let primaryTypeNames: Set<String> = ["record", "query", "procedure", "subscription", "permission-set"]

    let doc: LexiconDoc
    let options: LexiconSchemaOptions

    private enum Position {
        case main, named, property, items, parameter, parameterItems, body, message

        var label: String {
            switch self {
            case .main: return "the \"main\" definition"
            case .named: return "a named definition"
            case .property: return "an object property"
            case .items: return "array items"
            case .parameter: return "a query parameter"
            case .parameterItems: return "the items of an array query parameter"
            case .body: return "an XRPC body schema"
            case .message: return "a subscription message schema"
            }
        }
    }

    private func allows(_ position: Position, _ def: LexiconDef) -> Bool {
        switch def {
        case .record, .query, .procedure, .subscription, .permissionSet:
            return position == .main
        case .object:
            return [.main, .named, .property, .items, .body].contains(position)
        case .array:
            return [.main, .named, .property, .items, .parameter].contains(position)
        case .token:
            return position == .main || position == .named
        case .string, .integer, .boolean:
            return position != .body && position != .message
        case .bytes, .cidLink, .blob:
            return [.main, .named, .property, .items].contains(position)
        case .unknown:
            return [.property, .items, .parameter, .parameterItems].contains(position)
        case .ref:
            return [.property, .items, .body].contains(position)
        case .union:
            return [.property, .items, .body, .message].contains(position)
        case .params, .permission:
            return false
        case .unsupported:
            return options.allowUnknownDefinitionTypes
        }
    }

    private func fail(_ code: LexiconSchemaError.Code, _ path: String, _ message: String) -> LexiconSchemaError {
        LexiconSchemaError(code, nsid: doc.id, path: path, message)
    }

    func validate() throws {
        guard doc.lexicon == 1 else {
            throw fail(.unsupportedLexiconVersion, "/lexicon", "\"lexicon\" must be 1, found \(doc.lexicon)")
        }
        guard LexSyntax.isNSID(doc.id) else {
            throw fail(.invalidNSID, "/id", "\"\(doc.id)\" is not a valid NSID")
        }
        guard !doc.defs.isEmpty else {
            throw fail(.noDefinitions, "/defs", "a Lexicon must have at least one definition")
        }
        for name in doc.defs.keys.sorted() {
            guard let def = doc.defs[name] else { continue }
            let path = LexPath.appending("/defs", name)
            guard LexiconReference.isValidDefinitionName(name) else {
                throw fail(.invalidDefinitionName, path, "\"\(name)\" is not a valid definition name")
            }
            if def.isPrimary, name != "main" {
                throw fail(.primaryNotMain, path, "a \"\(def.typeName)\" definition must be named \"main\", not \"\(name)\"")
            }
            try check(def, path: path, position: name == "main" ? .main : .named)
        }
    }

    private func check(_ def: LexiconDef, path: String, position: Position, depth: Int = 0) throws {
        guard depth <= LexiconDocReader.maximumNesting else {
            throw fail(.nestingTooDeep, path, "definitions nest deeper than \(LexiconDocReader.maximumNesting) levels")
        }
        guard allows(position, def) else {
            if case .unsupported = def {
                throw fail(.unknownType, path + "/type", "\"\(def.typeName)\" is not a Lexicon type")
            }
            throw fail(.typeNotAllowed, path, "type \"\(def.typeName)\" can not be used as \(position.label)")
        }
        switch def {
        case let .record(record):
            guard record.keyType != nil else {
                throw fail(.invalidRecordKeyType, path + "/key", "\"\(record.key)\" is not a record key type (tid, nsid, any, literal:<value>)")
            }
            try checkObject(record.record, path: path + "/record", depth: depth + 1)
        case let .query(query):
            try checkParameters(query.parameters, path: path, depth: depth + 1)
            try checkBody(query.output, path: path + "/output", depth: depth)
            try checkErrors(query.errors, path: path)
        case let .procedure(procedure):
            try checkParameters(procedure.parameters, path: path, depth: depth + 1)
            try checkBody(procedure.input, path: path + "/input", depth: depth)
            try checkBody(procedure.output, path: path + "/output", depth: depth)
            try checkErrors(procedure.errors, path: path)
        case let .subscription(subscription):
            try checkParameters(subscription.parameters, path: path, depth: depth + 1)
            try check(subscription.message.schema, path: path + "/message/schema", position: .message, depth: depth + 1)
            try checkErrors(subscription.errors, path: path)
        case let .permissionSet(set):
            try checkPermissionSet(set, path: path)
        case let .object(object):
            try checkObject(object, path: path, depth: depth)
        case let .array(array):
            try checkRange(array.minLength, array.maxLength, "minLength", "maxLength", path: path)
            try check(array.items, path: path + "/items", position: position == .parameter ? .parameterItems : .items, depth: depth + 1)
        case let .string(string):
            try checkString(string, path: path)
        case let .integer(integer):
            try checkInteger(integer, path: path)
        case let .boolean(boolean):
            if boolean.constValue != nil, boolean.defaultValue != nil {
                throw fail(.invalidConstraint, path, "\"const\" and \"default\" are mutually exclusive")
            }
        case let .bytes(bytes):
            try checkRange(bytes.minLength, bytes.maxLength, "minLength", "maxLength", path: path)
        case let .blob(blob):
            for (index, pattern) in (blob.accept ?? []).enumerated() where !LexBlob.isValidAcceptPattern(pattern) {
                throw fail(
                    .invalidMIMEPattern,
                    LexPath.appending(path + "/accept", index),
                    "\"\(pattern)\" is not a supported accept pattern (use type/subtype, type/* or */*)"
                )
            }
            if let maxSize = blob.maxSize, maxSize < 0 {
                throw fail(.invalidConstraint, path + "/maxSize", "\"maxSize\" must not be negative")
            }
        case let .ref(ref):
            try checkReference(ref.ref, path: path + "/ref", inUnion: false)
        case let .union(union):
            if union.isClosed, union.refs.isEmpty {
                throw fail(.emptyClosedUnion, path, "a closed union must list at least one variant")
            }
            for (index, ref) in union.refs.enumerated() {
                try checkReference(ref, path: LexPath.appending(path + "/refs", index), inUnion: true)
            }
        case .token, .cidLink, .unknown, .unsupported, .params, .permission:
            break
        }
    }

    private func checkObject(_ object: LexObject, path: String, depth: Int) throws {
        try checkNames(object.required, key: "required", properties: object.properties, path: path)
        try checkNames(object.nullable, key: "nullable", properties: object.properties, path: path)
        for name in object.properties.keys.sorted() {
            guard let property = object.properties[name] else { continue }
            try check(property, path: LexPath.appending(path + "/properties", name), position: .property, depth: depth + 1)
        }
    }

    private func checkNames(_ names: [String]?, key: String, properties: [String: LexiconDef], path: String) throws {
        for (index, name) in (names ?? []).enumerated() where properties[name] == nil {
            throw fail(
                .undefinedProperty,
                LexPath.appending(path + "/" + key, index),
                "\"\(key)\" lists \"\(name)\", which is not a defined property"
            )
        }
    }

    private func checkParameters(_ parameters: LexParams?, path: String, depth: Int) throws {
        guard let parameters else { return }
        let path = path + "/parameters"
        try checkNames(parameters.required, key: "required", properties: parameters.properties, path: path)
        for name in parameters.properties.keys.sorted() {
            guard let property = parameters.properties[name] else { continue }
            try check(property, path: LexPath.appending(path + "/properties", name), position: .parameter, depth: depth + 1)
        }
    }

    private func checkBody(_ body: LexXRPCBody?, path: String, depth: Int) throws {
        guard let body else { return }
        guard !body.encoding.isEmpty else {
            throw fail(.invalidConstraint, path + "/encoding", "\"encoding\" must not be empty")
        }
        if let schema = body.schema {
            try check(schema, path: path + "/schema", position: .body, depth: depth + 1)
        }
    }

    private func checkErrors(_ errors: [LexXRPCError]?, path: String) throws {
        for (index, error) in (errors ?? []).enumerated() {
            let hasWhitespace = error.name.unicodeScalars.contains { $0.properties.isWhitespace }
            if error.name.isEmpty || hasWhitespace {
                throw fail(
                    .invalidConstraint,
                    LexPath.appending(path + "/errors", index) + "/name",
                    "an error name must be non-empty and contain no whitespace"
                )
            }
        }
    }

    private func checkPermissionSet(_ set: LexPermissionSet, path: String) throws {
        for (key, map) in [("title:lang", set.titleLang), ("detail:lang", set.detailLang)] {
            for tag in (map ?? [:]).keys.sorted() where !LexSyntax.isLanguageTag(tag) {
                throw fail(.invalidLanguageTag, LexPath.appending(path + "/" + key, tag), "\"\(tag)\" is not a language tag")
            }
        }
        for (index, permission) in set.permissions.enumerated() {
            let permissionPath = LexPath.appending(path + "/permissions", index)
            guard !permission.resource.isEmpty else {
                throw fail(.invalidConstraint, permissionPath + "/resource", "\"resource\" must not be empty")
            }
            for key in permission.parameters.keys.sorted() {
                guard let value = permission.parameters[key] else { continue }
                // Permission parameters are scalars or arrays of scalars.
                let scalars = value.arrayValue ?? [value]
                for scalar in scalars {
                    switch scalar {
                    case .string, .integer, .boolean:
                        continue
                    default:
                        throw fail(
                            .invalidFieldType,
                            LexPath.appending(permissionPath, key),
                            "a permission parameter must be a string, integer, boolean, or an array of those"
                        )
                    }
                }
            }
        }
    }

    private func checkRange(_ minimum: Int?, _ maximum: Int?, _ minimumKey: String, _ maximumKey: String, path: String) throws {
        if let minimum, minimum < 0 {
            throw fail(.invalidConstraint, path + "/" + minimumKey, "\"\(minimumKey)\" must not be negative")
        }
        if let maximum, maximum < 0 {
            throw fail(.invalidConstraint, path + "/" + maximumKey, "\"\(maximumKey)\" must not be negative")
        }
        if let minimum, let maximum, minimum > maximum {
            throw fail(.invalidConstraint, path, "\"\(minimumKey)\" (\(minimum)) is greater than \"\(maximumKey)\" (\(maximum))")
        }
    }

    private func checkString(_ string: LexString, path: String) throws {
        if let format = string.format, !format.isStandard, !options.allowUnknownStringFormats {
            throw fail(.unknownStringFormat, path + "/format", "\"\(format.rawValue)\" is not a Lexicon string format")
        }
        try checkRange(string.minLength, string.maxLength, "minLength", "maxLength", path: path)
        try checkRange(string.minGraphemes, string.maxGraphemes, "minGraphemes", "maxGraphemes", path: path)
        if string.constValue != nil, string.defaultValue != nil {
            throw fail(.invalidConstraint, path, "\"const\" and \"default\" are mutually exclusive")
        }
        if let defaultValue = string.defaultValue {
            var rules = string
            rules.defaultValue = nil
            if let violation = rules.violations(of: defaultValue).first {
                throw fail(.invalidConstraint, path + "/default", "the default value is not valid for this definition: \(violation.message)")
            }
        }
        if let constValue = string.constValue {
            var rules = string
            rules.constValue = nil
            if let violation = rules.violations(of: constValue).first {
                throw fail(.invalidConstraint, path + "/const", "the const value is not valid for this definition: \(violation.message)")
            }
        }
    }

    private func checkInteger(_ integer: LexInteger, path: String) throws {
        if let minimum = integer.minimum, let maximum = integer.maximum, minimum > maximum {
            throw fail(.invalidConstraint, path, "\"minimum\" (\(minimum)) is greater than \"maximum\" (\(maximum))")
        }
        if integer.constValue != nil, integer.defaultValue != nil {
            throw fail(.invalidConstraint, path, "\"const\" and \"default\" are mutually exclusive")
        }
        if let defaultValue = integer.defaultValue {
            var rules = integer
            rules.defaultValue = nil
            if let violation = rules.violations(of: defaultValue).first {
                throw fail(.invalidConstraint, path + "/default", "the default value is not valid for this definition: \(violation.message)")
            }
        }
        if let constValue = integer.constValue {
            var rules = integer
            rules.constValue = nil
            if let violation = rules.violations(of: constValue).first {
                throw fail(.invalidConstraint, path + "/const", "the const value is not valid for this definition: \(violation.message)")
            }
        }
    }

    private func checkReference(_ ref: String, path: String, inUnion: Bool) throws {
        guard let reference = LexiconReference(ref, relativeTo: doc.id) else {
            throw fail(.invalidReference, path, "\"\(ref)\" is not a valid reference (expected nsid, nsid#name or #name)")
        }
        // References into other documents are resolved when data is validated
        // (and by LexiconCatalog.referenceProblems()); only this document is
        // at hand here.
        guard reference.nsid == doc.id else { return }
        guard let target = doc.defs[reference.name] else {
            throw fail(.unresolvedReference, path, "\"\(ref)\" refers to \"\(reference.name)\", which this Lexicon does not define")
        }
        if let problem = LexiconSchemaValidator.referenceTargetProblem(target, inUnion: inUnion) {
            throw fail(.invalidReferenceTarget, path, "\"\(ref)\" \(problem)")
        }
    }

    /// Why `target` can not be the target of a `ref` (or a `union` variant),
    /// or `nil` if it can.
    static func referenceTargetProblem(_ target: LexiconDef, inUnion: Bool) -> String? {
        if inUnion {
            switch target {
            case .object, .record:
                return nil
            default:
                return "points at a \"\(target.typeName)\"; union variants must be objects or records"
            }
        }
        switch target {
        case .token:
            return "points at a token, which has no data representation"
        case .query, .procedure, .subscription, .permissionSet, .params, .permission, .ref, .union, .unknown, .unsupported:
            return "points at a \"\(target.typeName)\", which can not be referenced"
        case .record, .object, .array, .string, .integer, .boolean, .bytes, .cidLink, .blob:
            return nil
        }
    }
}
