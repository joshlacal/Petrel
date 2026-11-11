import Foundation

/// A set of Lexicon documents that data can be validated against.
///
/// `LexiconCatalog` is a value type: copy it freely, share it across tasks,
/// and build it once at start-up from the schemas an application understands.
///
/// ```swift
/// var catalog = LexiconCatalog()
/// try catalog.add(json: schemaJSON)
/// try catalog.validateRecord(record, collection: "com.example.note")
/// ```
///
/// Every `validate…` method throws ``LexiconValidationError`` when the data is
/// wrong and ``LexiconCatalogError`` when the schema it was asked to use is
/// not in the catalog (or is of the wrong kind).
///
/// The `validate…` methods check a value against a schema; they do not
/// re-check it against the data model. A ``LexValue`` produced by one of the
/// parsers always satisfies the data model. One assembled from Swift literals
/// might not (it could hold a `"$link"` key, or a malformed blob); run
/// ``LexValue/checkDataModel(options:)`` on such a value first.
public struct LexiconCatalog: Sendable {
    /// The documents in the catalog, keyed by NSID.
    public private(set) var documents: [String: LexiconDoc] = [:]

    /// Creates an empty catalog.
    public init() {}

    /// Creates a catalog from documents, validating each one.
    ///
    /// - Throws: ``LexiconSchemaError``.
    public init(_ documents: [LexiconDoc], options: LexiconSchemaOptions = .strict) throws {
        for document in documents {
            try add(document, options: options)
        }
    }

    // MARK: Contents

    /// Validates a document and adds it.
    ///
    /// - Parameters:
    ///   - document: The Lexicon document.
    ///   - options: How strictly to check it.
    ///   - replaceExisting: Replace a document with the same NSID instead of
    ///     failing with ``LexiconSchemaError/Code/duplicateLexicon``.
    /// - Throws: ``LexiconSchemaError``.
    public mutating func add(
        _ document: LexiconDoc,
        options: LexiconSchemaOptions = .strict,
        replaceExisting: Bool = false
    ) throws {
        try document.validate(options: options)
        guard replaceExisting || documents[document.id] == nil else {
            throw LexiconSchemaError(.duplicateLexicon, nsid: document.id, path: "/id", "\(document.id) is already in the catalog")
        }
        documents[document.id] = document
    }

    /// Parses a Lexicon JSON document, validates it and adds it.
    ///
    /// - Returns: The parsed document.
    /// - Throws: ``LexiconSchemaError``.
    @discardableResult
    public mutating func add(
        json: Data,
        options: LexiconSchemaOptions = .strict,
        replaceExisting: Bool = false
    ) throws -> LexiconDoc {
        let document = try LexiconDoc(json: json, options: options)
        try add(document, options: options, replaceExisting: replaceExisting)
        return document
    }

    /// Adds every `.json` file under a directory, searching subdirectories.
    ///
    /// Files are added in path order. The first file that can not be read or
    /// is not a valid Lexicon stops the load and throws; documents added
    /// before it stay in the catalog.
    ///
    /// - Returns: The documents that were added.
    /// - Throws: ``LexiconSchemaError`` for an invalid document, or the file
    ///   system error for an unreadable file or directory.
    @discardableResult
    public mutating func add(
        contentsOfDirectory directory: URL,
        options: LexiconSchemaOptions = .strict,
        replaceExisting: Bool = false
    ) throws -> [LexiconDoc] {
        var files: [URL] = []
        var pending = [directory]
        while let current = pending.popLast() {
            let entries = try FileManager.default.contentsOfDirectory(
                at: current,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            for entry in entries {
                if try entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true {
                    pending.append(entry)
                } else if entry.pathExtension == "json" {
                    files.append(entry)
                }
            }
        }
        var added: [LexiconDoc] = []
        for file in files.sorted(by: { $0.path < $1.path }) {
            try added.append(add(json: Data(contentsOf: file), options: options, replaceExisting: replaceExisting))
        }
        return added
    }

    /// Removes a document.
    ///
    /// - Returns: The removed document, or `nil` if there was none.
    @discardableResult
    public mutating func remove(_ nsid: String) -> LexiconDoc? {
        documents.removeValue(forKey: nsid)
    }

    /// The NSIDs in the catalog, sorted.
    public var nsids: [String] {
        documents.keys.sorted()
    }

    /// The document for an NSID.
    public func document(_ nsid: String) -> LexiconDoc? {
        documents[nsid]
    }

    /// Looks up a definition by reference: `nsid` (the `main` definition),
    /// `nsid#main`, or `nsid#name`.
    public func definition(_ reference: String) -> LexiconDef? {
        guard let parsed = LexiconReference(reference) else { return nil }
        return definition(parsed)
    }

    /// Looks up a definition by parsed reference.
    public func definition(_ reference: LexiconReference) -> LexiconDef? {
        documents[reference.nsid]?.defs[reference.name]
    }

    /// Looks up a definition by a reference written inside a document, where
    /// `#name` means "in the same document".
    public func definition(_ reference: String, relativeTo nsid: String) -> LexiconDef? {
        guard let parsed = LexiconReference(reference, relativeTo: nsid) else { return nil }
        return definition(parsed)
    }

    /// Every `ref` and `union` reference in the catalog that does not resolve,
    /// or that resolves to a definition it may not point at (a `token`; a
    /// non-object union variant). An empty result means the catalog is closed
    /// under reference and every schema in it can be fully checked.
    public func referenceProblems() -> [LexiconSchemaError] {
        var problems: [LexiconSchemaError] = []
        for nsid in nsids {
            guard let document = documents[nsid] else { continue }
            for name in document.defs.keys.sorted() {
                guard let def = document.defs[name] else { continue }
                def.forEachReference(path: LexPath.appending("/defs", name)) { ref, path, inUnion in
                    guard let reference = LexiconReference(ref, relativeTo: nsid) else {
                        problems.append(LexiconSchemaError(.invalidReference, nsid: nsid, path: path, "\"\(ref)\" is not a valid reference"))
                        return
                    }
                    guard let target = definition(reference) else {
                        problems.append(LexiconSchemaError(.unresolvedReference, nsid: nsid, path: path, "\(reference) is not in the catalog"))
                        return
                    }
                    if let problem = LexiconSchemaValidator.referenceTargetProblem(target, inUnion: inUnion) {
                        problems.append(LexiconSchemaError(.invalidReferenceTarget, nsid: nsid, path: path, "\"\(ref)\" \(problem)"))
                    }
                }
            }
        }
        return problems
    }

    private func resolve(_ reference: String, expecting expected: [String]) throws -> (LexiconReference, LexiconDef) {
        guard let parsed = LexiconReference(reference) else {
            throw LexiconCatalogError.invalidReference(reference)
        }
        guard let def = definition(parsed) else {
            throw LexiconCatalogError.definitionNotFound(parsed.description)
        }
        guard expected.isEmpty || expected.contains(def.typeName) else {
            throw LexiconCatalogError.definitionTypeMismatch(reference: parsed.description, expected: expected, actual: def.typeName)
        }
        return (parsed, def)
    }

    // MARK: Records and objects

    /// Validates a repository record.
    ///
    /// The value must be an object whose `$type` is exactly `collection` (a
    /// `#main` suffix is not allowed), and must satisfy the record schema.
    /// Properties the schema does not define are ignored.
    ///
    /// - Parameters:
    ///   - record: The record value.
    ///   - collection: The NSID of the record type.
    ///   - recordKey: When given, also checked against the record's `key`
    ///     type (`tid`, `nsid`, `any`, `literal:<value>`).
    ///   - options: Validation options.
    /// - Throws: ``LexiconValidationError`` or ``LexiconCatalogError``.
    public func validateRecord(
        _ record: LexValue,
        collection: String,
        recordKey: String? = nil,
        options: LexiconValidationOptions = .standard
    ) throws {
        let (reference, def) = try resolve(collection, expecting: ["record"])
        guard case let .record(schema) = def else { return }
        var validator = LexiconDataValidator(catalog: self, options: options)
        if let recordKey, let keyType = schema.keyType, !keyType.accepts(recordKey) {
            validator.report(.recordKeyMismatch, "", "record key \"\(recordKey)\" does not satisfy the key type \"\(schema.key)\"")
        }
        guard case let .object(fields) = record else {
            validator.report(.typeMismatch, "", "a record must be an object, found \(record.kind)")
            return try validator.finish()
        }
        if let type = fields["$type"]?.stringValue {
            if type != reference.description {
                validator.report(.invalidTypeDiscriminator, "/$type", "$type must be \"\(reference)\", found \"\(type)\"")
            }
        } else {
            validator.report(.missingTypeDiscriminator, "/$type", "a record must include \"$type\": \"\(reference)\"")
        }
        validator.validateObject(record, schema.record, base: reference.nsid, path: "")
        try validator.finish()
    }

    /// Validates a value against any definition that describes data.
    ///
    /// - Parameters:
    ///   - value: The value.
    ///   - reference: `nsid` or `nsid#name`. A `record` definition is checked
    ///     as its object schema, without requiring `$type`.
    ///   - options: Validation options.
    /// - Throws: ``LexiconValidationError`` or ``LexiconCatalogError``.
    public func validate(
        _ value: LexValue,
        againstDef reference: String,
        options: LexiconValidationOptions = .standard
    ) throws {
        let (parsed, def) = try resolve(reference, expecting: [])
        var validator = LexiconDataValidator(catalog: self, options: options)
        validator.validate(value, def, base: parsed.nsid, path: "")
        try validator.finish()
    }

    // MARK: XRPC

    /// Validates the request body of a procedure against its `input` schema.
    /// A procedure without an input schema accepts any body.
    ///
    /// - Throws: ``LexiconValidationError`` or ``LexiconCatalogError``.
    public func validateXRPCInput(
        _ body: LexValue,
        nsid: String,
        options: LexiconValidationOptions = .standard
    ) throws {
        let (reference, def) = try resolve(nsid, expecting: ["procedure"])
        guard case let .procedure(procedure) = def, let schema = procedure.input?.schema else { return }
        var validator = LexiconDataValidator(catalog: self, options: options)
        validator.validateBody(body, schema, base: reference.nsid)
        try validator.finish()
    }

    /// Validates the response body of a query or procedure against its
    /// `output` schema. An endpoint without an output schema accepts any body.
    ///
    /// - Throws: ``LexiconValidationError`` or ``LexiconCatalogError``.
    public func validateXRPCOutput(
        _ body: LexValue,
        nsid: String,
        options: LexiconValidationOptions = .standard
    ) throws {
        let (reference, def) = try resolve(nsid, expecting: ["query", "procedure"])
        let output: LexXRPCBody?
        switch def {
        case let .query(query): output = query.output
        case let .procedure(procedure): output = procedure.output
        default: output = nil
        }
        guard let schema = output?.schema else { return }
        var validator = LexiconDataValidator(catalog: self, options: options)
        validator.validateBody(body, schema, base: reference.nsid)
        try validator.finish()
    }

    /// Validates one message of a subscription against its `message` union.
    ///
    /// - Parameters:
    ///   - message: The message body.
    ///   - nsid: The subscription's NSID.
    ///   - type: The variant named by the frame header (`t`, for example
    ///     `"#commit"`). Event-stream bodies carry no `$type`, so pass the
    ///     header value here. When `nil`, the body's own `$type` is required,
    ///     as for any other union.
    ///   - options: Validation options.
    /// - Throws: ``LexiconValidationError`` or ``LexiconCatalogError``.
    public func validateSubscriptionMessage(
        _ message: LexValue,
        nsid: String,
        type: String? = nil,
        options: LexiconValidationOptions = .standard
    ) throws {
        let (reference, def) = try resolve(nsid, expecting: ["subscription"])
        guard case let .subscription(subscription) = def else { return }
        var validator = LexiconDataValidator(catalog: self, options: options)
        validator.validateBody(message, subscription.message.schema, base: reference.nsid, explicitType: type)
        try validator.finish()
    }

    /// Decodes and validates the HTTP query parameters of a query, procedure
    /// or subscription.
    ///
    /// Query strings are untyped, so each value is coerced by the declared
    /// type: `boolean` accepts exactly `true` / `false`, `integer` accepts an
    /// optionally signed decimal that fits 64 bits, `string` is taken as is,
    /// and an `array` parameter collects every occurrence of its name. An
    /// empty value (`?cursor=`) is treated as absent, as the reference server
    /// does. Declared defaults are filled in, then `required` and every
    /// constraint are checked. Parameters the schema does not define are
    /// ignored.
    ///
    /// - Returns: The typed parameters, including defaults.
    /// - Throws: ``LexiconValidationError`` or ``LexiconCatalogError``.
    @discardableResult
    public func validateXRPCParameters(
        _ queryItems: [URLQueryItem],
        nsid: String,
        options: LexiconValidationOptions = .standard
    ) throws -> [String: LexValue] {
        let (reference, parameters) = try resolveParameters(nsid)
        var validator = LexiconDataValidator(catalog: self, options: options)
        var raw: [String: [String]] = [:]
        for item in queryItems {
            guard let value = item.value, !value.isEmpty else { continue }
            raw[item.name, default: []].append(value)
        }
        var decoded: [String: LexValue] = [:]
        for name in (parameters?.properties ?? [:]).keys.sorted() {
            guard let property = parameters?.properties[name], let values = raw[name] else { continue }
            let path = LexPath.appending("", name)
            if case let .array(array) = property {
                var items: [LexValue] = []
                for (index, value) in values.enumerated() {
                    if let item = LexiconCatalog.coerce(value, to: array.items, path: LexPath.appending(path, index), validator: &validator) {
                        items.append(item)
                    }
                }
                decoded[name] = .array(items)
            } else {
                guard values.count == 1 else {
                    validator.report(.repeatedParameter, path, "parameter \"\(name)\" is not an array and was given \(values.count) times")
                    continue
                }
                decoded[name] = LexiconCatalog.coerce(values[0], to: property, path: path, validator: &validator)
            }
        }
        // A value that failed coercion is already reported; do not also call
        // it missing.
        let attempted = Set(raw.keys)
        return try finishParameters(decoded, parameters, base: reference.nsid, attempted: attempted, validator: &validator)
    }

    /// Validates already-typed parameters (for example a decoded JSON object,
    /// or the parameters a client is about to send). Defaults are filled in,
    /// then `required` and every constraint are checked.
    ///
    /// - Returns: The parameters, including defaults.
    /// - Throws: ``LexiconValidationError`` or ``LexiconCatalogError``.
    @discardableResult
    public func validateXRPCParameters(
        _ parameters: LexValue,
        nsid: String,
        options: LexiconValidationOptions = .standard
    ) throws -> [String: LexValue] {
        let (reference, schema) = try resolveParameters(nsid)
        var validator = LexiconDataValidator(catalog: self, options: options)
        guard case let .object(fields) = parameters else {
            validator.report(.typeMismatch, "", "parameters must be an object, found \(parameters.kind)")
            try validator.finish()
            return [:]
        }
        return try finishParameters(fields, schema, base: reference.nsid, attempted: [], validator: &validator)
    }

    private func resolveParameters(_ nsid: String) throws -> (LexiconReference, LexParams?) {
        let (reference, def) = try resolve(nsid, expecting: ["query", "procedure", "subscription"])
        switch def {
        case let .query(query): return (reference, query.parameters)
        case let .procedure(procedure): return (reference, procedure.parameters)
        case let .subscription(subscription): return (reference, subscription.parameters)
        default: return (reference, nil)
        }
    }

    private func finishParameters(
        _ given: [String: LexValue],
        _ schema: LexParams?,
        base: String,
        attempted: Set<String>,
        validator: inout LexiconDataValidator
    ) throws -> [String: LexValue] {
        var result: [String: LexValue] = [:]
        let required = Set(schema?.required ?? [])
        for name in (schema?.properties ?? [:]).keys.sorted() {
            guard let property = schema?.properties[name] else { continue }
            let path = LexPath.appending("", name)
            guard let value = given[name] else {
                if let fallback = property.defaultLexValue {
                    result[name] = fallback
                } else if required.contains(name), !attempted.contains(name) {
                    validator.report(.missingRequiredProperty, path, "required parameter \"\(name)\" is missing")
                }
                continue
            }
            result[name] = value
            // `unknown` in a query string has no object form to check.
            if case .unknown = property { continue }
            if case let .array(array) = property, case .unknown = array.items {
                guard case .array = value else {
                    validator.report(.typeMismatch, path, "must be an array, found \(value.kind)")
                    continue
                }
                continue
            }
            validator.validate(value, property, base: base, path: path)
        }
        try validator.finish()
        return result
    }

    private static func coerce(
        _ raw: String,
        to def: LexiconDef,
        path: String,
        validator: inout LexiconDataValidator
    ) -> LexValue? {
        switch def {
        case .boolean:
            switch raw {
            case "true": return .boolean(true)
            case "false": return .boolean(false)
            default:
                validator.report(.typeMismatch, path, "must be \"true\" or \"false\", found \"\(raw)\"")
                return nil
            }
        case .integer:
            let digits = raw.hasPrefix("-") ? raw.dropFirst() : Substring(raw)
            guard !digits.isEmpty, digits.utf8.allSatisfy({ $0 >= 0x30 && $0 <= 0x39 }), let number = Int64(raw) else {
                validator.report(.typeMismatch, path, "must be a decimal integer, found \"\(raw)\"")
                return nil
            }
            return .integer(number)
        default:
            return .string(raw)
        }
    }
}

extension LexiconDef {
    /// The declared default of a boolean, integer or string definition.
    var defaultLexValue: LexValue? {
        switch self {
        case let .boolean(def): return def.defaultValue.map(LexValue.boolean)
        case let .integer(def): return def.defaultValue.map(LexValue.integer)
        case let .string(def): return def.defaultValue.map(LexValue.string)
        default: return nil
        }
    }

    /// Calls `body` for every reference inside this definition.
    func forEachReference(path: String, _ body: (_ ref: String, _ path: String, _ inUnion: Bool) -> Void) {
        func visitBody(_ schema: LexiconDef?, _ path: String) {
            schema?.forEachReference(path: path, body)
        }
        func visitProperties(_ properties: [String: LexiconDef], _ path: String) {
            for name in properties.keys.sorted() {
                properties[name]?.forEachReference(path: LexPath.appending(path + "/properties", name), body)
            }
        }
        switch self {
        case let .ref(ref):
            body(ref.ref, path + "/ref", false)
        case let .union(union):
            for (index, ref) in union.refs.enumerated() {
                body(ref, LexPath.appending(path + "/refs", index), true)
            }
        case let .object(object):
            visitProperties(object.properties, path)
        case let .params(params):
            visitProperties(params.properties, path)
        case let .array(array):
            array.items.forEachReference(path: path + "/items", body)
        case let .record(record):
            visitProperties(record.record.properties, path + "/record")
        case let .query(query):
            if let parameters = query.parameters {
                visitProperties(parameters.properties, path + "/parameters")
            }
            visitBody(query.output?.schema, path + "/output/schema")
        case let .procedure(procedure):
            if let parameters = procedure.parameters {
                visitProperties(parameters.properties, path + "/parameters")
            }
            visitBody(procedure.input?.schema, path + "/input/schema")
            visitBody(procedure.output?.schema, path + "/output/schema")
        case let .subscription(subscription):
            if let parameters = subscription.parameters {
                visitProperties(parameters.properties, path + "/parameters")
            }
            visitBody(subscription.message.schema, path + "/message/schema")
        case .permissionSet, .token, .string, .integer, .boolean, .bytes, .cidLink, .blob, .unknown, .permission, .unsupported:
            break
        }
    }
}
