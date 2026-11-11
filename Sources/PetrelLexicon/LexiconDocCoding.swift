import Foundation

// MARK: - Reading

public extension LexiconDoc {
    /// Parses and validates a Lexicon JSON document.
    ///
    /// Fields the language does not define are ignored, so documents written
    /// for a later revision still load. `$type` is tolerated, which lets a
    /// `com.atproto.lexicon.schema` record be passed directly.
    ///
    /// - Throws: ``LexiconSchemaError``.
    init(json: Data, options: LexiconSchemaOptions = .strict) throws {
        let value: LexValue
        do {
            value = try LexValue(json: json)
        } catch let error as LexValueError {
            throw LexiconSchemaError(.malformedDocument, path: error.path, error.message)
        }
        try self.init(value, options: options)
    }

    /// Parses and validates a Lexicon document held as a ``LexValue``.
    ///
    /// - Throws: ``LexiconSchemaError``.
    init(_ value: LexValue, options: LexiconSchemaOptions = .strict) throws {
        self = try LexiconDocReader(options: options).readDoc(value)
        try validate(options: options)
    }

    /// The document as a data-model value, ready to serialize or to publish as
    /// a `com.atproto.lexicon.schema` record (add `$type` for the latter).
    var lexValue: LexValue {
        var fields: [String: LexValue] = [
            "lexicon": .integer(Int64(lexicon)),
            "id": .string(id),
            "defs": .object(defs.mapValues(\.lexValue)),
        ]
        fields["revision"] = revision.map(LexValue.integer)
        fields["description"] = description.map(LexValue.string)
        return .object(fields)
    }

    /// The document as JSON with sorted keys.
    func jsonData() -> Data {
        lexValue.jsonData()
    }
}

extension LexiconDoc: Codable {
    /// Decodes and validates with ``LexiconSchemaOptions/strict``.
    public init(from decoder: Decoder) throws {
        let value = try LexValue(from: decoder)
        do {
            try self.init(value, options: .strict)
        } catch let error as LexiconSchemaError {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: error.description, underlyingError: error)
            )
        }
    }

    /// Encodes the document in the JSON shape of a Lexicon file.
    public func encode(to encoder: Encoder) throws {
        try lexValue.encode(to: encoder)
    }
}

extension LexiconDef: Codable {
    /// Decodes one definition. Structure is checked; the position rules of a
    /// whole document are only checked by ``LexiconDoc/validate(options:)``.
    public init(from decoder: Decoder) throws {
        let value = try LexValue(from: decoder)
        do {
            self = try LexiconDocReader(options: .strict).readDef(value, path: "")
        } catch let error as LexiconSchemaError {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: error.description, underlyingError: error)
            )
        }
    }

    /// Encodes the definition in the JSON shape a Lexicon file uses.
    public func encode(to encoder: Encoder) throws {
        try lexValue.encode(to: encoder)
    }
}

/// Typed access to the fields of one JSON object of a Lexicon document.
struct LexiconFields {
    let fields: [String: LexValue]
    let path: String

    init(_ value: LexValue, path: String) throws {
        guard case let .object(fields) = value else {
            throw LexiconSchemaError(.invalidFieldType, path: path, "expected an object, found \(value.kind)")
        }
        self.fields = fields
        self.path = path
    }

    func path(_ key: String) -> String {
        LexPath.appending(path, key)
    }

    private func wrongType(_ key: String, _ expected: String) -> LexiconSchemaError {
        LexiconSchemaError(.invalidFieldType, path: path(key), "\"\(key)\" must be \(expected), found \(fields[key]?.kind ?? "nothing")")
    }

    private func missing(_ key: String) -> LexiconSchemaError {
        LexiconSchemaError(.missingField, path: path(key), "required field \"\(key)\" is missing")
    }

    func string(_ key: String) throws -> String? {
        guard let value = fields[key] else { return nil }
        guard let string = value.stringValue else { throw wrongType(key, "a string") }
        return string
    }

    func requiredString(_ key: String) throws -> String {
        guard let string = try string(key) else { throw missing(key) }
        return string
    }

    func integer(_ key: String) throws -> Int64? {
        guard let value = fields[key] else { return nil }
        guard let number = value.integerValue else { throw wrongType(key, "an integer") }
        return number
    }

    /// A length or size, which is kept as `Int`.
    func count(_ key: String) throws -> Int? {
        guard let number = try integer(key) else { return nil }
        guard let count = Int(exactly: number) else { throw wrongType(key, "an integer") }
        return count
    }

    func bool(_ key: String) throws -> Bool? {
        guard let value = fields[key] else { return nil }
        guard let flag = value.boolValue else { throw wrongType(key, "a boolean") }
        return flag
    }

    func strings(_ key: String) throws -> [String]? {
        guard let value = fields[key] else { return nil }
        guard let items = value.arrayValue else { throw wrongType(key, "an array of strings") }
        return try items.map { item in
            guard let string = item.stringValue else { throw wrongType(key, "an array of strings") }
            return string
        }
    }

    func integers(_ key: String) throws -> [Int64]? {
        guard let value = fields[key] else { return nil }
        guard let items = value.arrayValue else { throw wrongType(key, "an array of integers") }
        return try items.map { item in
            guard let number = item.integerValue else { throw wrongType(key, "an array of integers") }
            return number
        }
    }

    func stringMap(_ key: String) throws -> [String: String]? {
        guard let value = fields[key] else { return nil }
        guard let entries = value.objectValue else { throw wrongType(key, "a map of strings") }
        return try entries.mapValues { entry in
            guard let string = entry.stringValue else { throw wrongType(key, "a map of strings") }
            return string
        }
    }

    func value(_ key: String) -> LexValue? {
        fields[key]
    }

    func required(_ key: String) throws -> LexValue {
        guard let value = fields[key] else { throw missing(key) }
        return value
    }
}

/// Turns data-model values into the Lexicon model. Only structure is checked
/// here (field presence and JSON types); the rules of the language live in
/// `LexiconSchemaValidator`.
struct LexiconDocReader {
    let options: LexiconSchemaOptions

    func readDoc(_ value: LexValue) throws -> LexiconDoc {
        guard case .object = value else {
            throw LexiconSchemaError(.malformedDocument, path: "", "a Lexicon document must be an object, found \(value.kind)")
        }
        let fields = try LexiconFields(value, path: "")
        guard case let .integer(version)? = fields.value("lexicon"), version == 1 else {
            throw LexiconSchemaError(.unsupportedLexiconVersion, path: "/lexicon", "\"lexicon\" must be the integer 1")
        }
        guard case let .string(id)? = fields.value("id"), LexSyntax.isNSID(id) else {
            throw LexiconSchemaError(.invalidNSID, path: "/id", "\"id\" must be a valid NSID")
        }
        do {
            guard let defsValue = fields.value("defs") else {
                throw LexiconSchemaError(.noDefinitions, path: "/defs", "\"defs\" is missing")
            }
            let defFields = try LexiconFields(defsValue, path: "/defs")
            var defs: [String: LexiconDef] = [:]
            for (name, defValue) in defFields.fields {
                // Reported before the definition's own fields are read, so a
                // misplaced primary type is named as such.
                if name != "main", let type = defValue["type"]?.stringValue, LexiconSchemaValidator.primaryTypeNames.contains(type) {
                    throw LexiconSchemaError(
                        .primaryNotMain,
                        path: defFields.path(name),
                        "a \"\(type)\" definition must be named \"main\", not \"\(name)\""
                    )
                }
                defs[name] = try readDef(defValue, path: defFields.path(name))
            }
            return try LexiconDoc(
                lexicon: 1,
                id: id,
                revision: fields.integer("revision"),
                description: fields.string("description"),
                defs: defs
            )
        } catch let error as LexiconSchemaError {
            throw error.with(nsid: id)
        }
    }

    /// Definitions nested deeper than this are rejected. Real schemas nest a
    /// handful of levels; the limit keeps a hostile document from driving
    /// the recursive reader and validator arbitrarily deep.
    static let maximumNesting = 32

    /// Reads one definition. Each type is read by its own small function so
    /// that the recursive path (object properties, array items, bodies) keeps
    /// a small stack frame per level.
    func readDef(_ value: LexValue, path: String, depth: Int = 0) throws -> LexiconDef {
        guard depth <= LexiconDocReader.maximumNesting else {
            throw LexiconSchemaError(.nestingTooDeep, path: path, "definitions nest deeper than \(LexiconDocReader.maximumNesting) levels")
        }
        let fields = try LexiconFields(value, path: path)
        let type = try fields.requiredString("type")
        switch type {
        case "record": return try .record(readRecord(fields, depth: depth))
        case "query": return try .query(readQuery(fields, depth: depth))
        case "procedure": return try .procedure(readProcedure(fields, depth: depth))
        case "subscription": return try .subscription(readSubscription(fields, depth: depth))
        case "permission-set": return try .permissionSet(readPermissionSet(fields))
        case "object": return try .object(readObject(fields, depth: depth))
        case "params": return try .params(readParams(fields, depth: depth))
        case "permission": return try .permission(readPermission(fields))
        case "array": return try .array(readArray(fields, depth: depth))
        case "token": return try .token(LexToken(description: fields.string("description")))
        case "string": return try .string(readString(fields))
        case "integer": return try .integer(readInteger(fields))
        case "boolean": return try .boolean(readBoolean(fields))
        case "bytes": return try .bytes(readBytes(fields))
        case "cid-link": return try .cidLink(LexCIDLink(description: fields.string("description")))
        case "blob": return try .blob(readBlob(fields))
        case "unknown": return try .unknown(LexUnknown(description: fields.string("description")))
        case "ref": return try .ref(LexRef(description: fields.string("description"), ref: fields.requiredString("ref")))
        case "union": return try .union(readUnion(fields))
        default:
            guard options.allowUnknownDefinitionTypes else {
                throw LexiconSchemaError(.unknownType, path: fields.path("type"), "\"\(type)\" is not a Lexicon type")
            }
            // The description must still be a string if present.
            _ = try fields.string("description")
            return .unsupported(LexUnsupportedDef(type: type, raw: value))
        }
    }

    private func readRecord(_ fields: LexiconFields, depth: Int) throws -> LexRecord {
        try LexRecord(
            description: fields.string("description"),
            key: fields.requiredString("key"),
            record: readNestedObject(fields.required("record"), path: fields.path("record"), depth: depth + 1)
        )
    }

    private func readQuery(_ fields: LexiconFields, depth: Int) throws -> LexXRPCQuery {
        try LexXRPCQuery(
            description: fields.string("description"),
            parameters: readParameters(fields, depth: depth),
            output: readBody(fields, "output", depth: depth),
            errors: readErrors(fields)
        )
    }

    private func readProcedure(_ fields: LexiconFields, depth: Int) throws -> LexXRPCProcedure {
        try LexXRPCProcedure(
            description: fields.string("description"),
            parameters: readParameters(fields, depth: depth),
            input: readBody(fields, "input", depth: depth),
            output: readBody(fields, "output", depth: depth),
            errors: readErrors(fields)
        )
    }

    private func readSubscription(_ fields: LexiconFields, depth: Int) throws -> LexXRPCSubscription {
        let description = try fields.string("description")
        let parameters = try readParameters(fields, depth: depth)
        let message = try LexiconFields(fields.required("message"), path: fields.path("message"))
        return try LexXRPCSubscription(
            description: description,
            parameters: parameters,
            message: LexXRPCMessage(
                description: message.string("description"),
                schema: readDef(message.required("schema"), path: message.path("schema"), depth: depth + 1)
            ),
            errors: readErrors(fields)
        )
    }

    private func readPermissionSet(_ fields: LexiconFields) throws -> LexPermissionSet {
        let description = try fields.string("description")
        let permissionsPath = fields.path("permissions")
        guard let items = try fields.required("permissions").arrayValue else {
            throw LexiconSchemaError(.invalidFieldType, path: permissionsPath, "\"permissions\" must be an array")
        }
        let permissions = try items.enumerated().map { index, item in
            try readPermission(LexiconFields(item, path: LexPath.appending(permissionsPath, index)))
        }
        return try LexPermissionSet(
            description: description,
            title: fields.string("title"),
            titleLang: fields.stringMap("title:lang"),
            detail: fields.string("detail"),
            detailLang: fields.stringMap("detail:lang"),
            permissions: permissions
        )
    }

    private func readArray(_ fields: LexiconFields, depth: Int) throws -> LexArray {
        try LexArray(
            description: fields.string("description"),
            items: readDef(fields.required("items"), path: fields.path("items"), depth: depth + 1),
            minLength: fields.count("minLength"),
            maxLength: fields.count("maxLength")
        )
    }

    private func readString(_ fields: LexiconFields) throws -> LexString {
        try LexString(
            description: fields.string("description"),
            format: fields.string("format").map(LexStringFormat.init(rawValue:)),
            minLength: fields.count("minLength"),
            maxLength: fields.count("maxLength"),
            minGraphemes: fields.count("minGraphemes"),
            maxGraphemes: fields.count("maxGraphemes"),
            knownValues: fields.strings("knownValues"),
            enumValues: fields.strings("enum"),
            defaultValue: fields.string("default"),
            constValue: fields.string("const")
        )
    }

    private func readInteger(_ fields: LexiconFields) throws -> LexInteger {
        try LexInteger(
            description: fields.string("description"),
            minimum: fields.integer("minimum"),
            maximum: fields.integer("maximum"),
            enumValues: fields.integers("enum"),
            defaultValue: fields.integer("default"),
            constValue: fields.integer("const")
        )
    }

    private func readBoolean(_ fields: LexiconFields) throws -> LexBoolean {
        try LexBoolean(
            description: fields.string("description"),
            defaultValue: fields.bool("default"),
            constValue: fields.bool("const")
        )
    }

    private func readBytes(_ fields: LexiconFields) throws -> LexBytes {
        try LexBytes(
            description: fields.string("description"),
            minLength: fields.count("minLength"),
            maxLength: fields.count("maxLength")
        )
    }

    private func readBlob(_ fields: LexiconFields) throws -> LexBlob {
        try LexBlob(
            description: fields.string("description"),
            accept: fields.strings("accept"),
            maxSize: fields.integer("maxSize")
        )
    }

    private func readUnion(_ fields: LexiconFields) throws -> LexUnion {
        let description = try fields.string("description")
        guard let refs = try fields.strings("refs") else {
            throw LexiconSchemaError(.missingField, path: fields.path("refs"), "required field \"refs\" is missing")
        }
        return try LexUnion(description: description, refs: refs, closed: fields.bool("closed"))
    }

    private func readProperties(_ fields: LexiconFields, depth: Int) throws -> [String: LexiconDef] {
        let properties = try LexiconFields(fields.required("properties"), path: fields.path("properties"))
        var result: [String: LexiconDef] = [:]
        for (name, value) in properties.fields {
            result[name] = try readDef(value, path: properties.path(name), depth: depth + 1)
        }
        return result
    }

    private func readObject(_ fields: LexiconFields, depth: Int) throws -> LexObject {
        try LexObject(
            description: fields.string("description"),
            properties: readProperties(fields, depth: depth),
            required: fields.strings("required"),
            nullable: fields.strings("nullable")
        )
    }

    /// Reads a value that must be a definition of type `object` (the `record`
    /// field of a record definition).
    private func readNestedObject(_ value: LexValue, path: String, depth: Int) throws -> LexObject {
        let fields = try LexiconFields(value, path: path)
        guard try fields.requiredString("type") == "object" else {
            throw LexiconSchemaError(.invalidFieldType, path: fields.path("type"), "expected a definition of type \"object\"")
        }
        return try readObject(fields, depth: depth)
    }

    private func readParams(_ fields: LexiconFields, depth: Int) throws -> LexParams {
        try LexParams(
            description: fields.string("description"),
            properties: readProperties(fields, depth: depth),
            required: fields.strings("required")
        )
    }

    private func readParameters(_ fields: LexiconFields, depth: Int) throws -> LexParams? {
        guard let value = fields.value("parameters") else { return nil }
        let parameters = try LexiconFields(value, path: fields.path("parameters"))
        guard try parameters.requiredString("type") == "params" else {
            throw LexiconSchemaError(.invalidFieldType, path: parameters.path("type"), "expected a definition of type \"params\"")
        }
        return try readParams(parameters, depth: depth + 1)
    }

    private func readBody(_ fields: LexiconFields, _ key: String, depth: Int) throws -> LexXRPCBody? {
        guard let value = fields.value(key) else { return nil }
        let body = try LexiconFields(value, path: fields.path(key))
        return try LexXRPCBody(
            description: body.string("description"),
            encoding: body.requiredString("encoding"),
            schema: body.value("schema").map { try readDef($0, path: body.path("schema"), depth: depth + 1) }
        )
    }

    private func readErrors(_ fields: LexiconFields) throws -> [LexXRPCError]? {
        guard let value = fields.value("errors") else { return nil }
        let errorsPath = fields.path("errors")
        guard let items = value.arrayValue else {
            throw LexiconSchemaError(.invalidFieldType, path: errorsPath, "\"errors\" must be an array")
        }
        return try items.enumerated().map { index, item in
            let error = try LexiconFields(item, path: LexPath.appending(errorsPath, index))
            return try LexXRPCError(name: error.requiredString("name"), description: error.string("description"))
        }
    }

    private func readPermission(_ fields: LexiconFields) throws -> LexPermission {
        guard try fields.requiredString("type") == "permission" else {
            throw LexiconSchemaError(.invalidFieldType, path: fields.path("type"), "expected a definition of type \"permission\"")
        }
        var parameters = fields.fields
        parameters["type"] = nil
        parameters["resource"] = nil
        return try LexPermission(resource: fields.requiredString("resource"), parameters: parameters)
    }
}

// MARK: - Writing

private extension Dictionary where Key == String, Value == LexValue {
    /// Builds an object from optional fields, dropping the absent ones.
    init(type: String, _ entries: KeyValuePairs<String, LexValue?>) {
        self.init()
        self["type"] = .string(type)
        for (key, value) in entries {
            self[key] = value
        }
    }
}

private func lexStrings(_ strings: [String]?) -> LexValue? {
    strings.map { .array($0.map(LexValue.string)) }
}

private func lexCount(_ count: Int?) -> LexValue? {
    count.map { .integer(Int64($0)) }
}

public extension LexiconDef {
    /// The definition as a data-model value, in the shape a Lexicon document
    /// uses.
    var lexValue: LexValue {
        switch self {
        case let .record(def):
            return .object(Dictionary(type: "record", [
                "description": def.description.map(LexValue.string),
                "key": .string(def.key),
                "record": def.record.lexValue,
            ]))
        case let .query(def):
            return .object(Dictionary(type: "query", [
                "description": def.description.map(LexValue.string),
                "parameters": def.parameters?.lexValue,
                "output": def.output?.lexValue,
                "errors": def.errors.map { .array($0.map(\.lexValue)) },
            ]))
        case let .procedure(def):
            return .object(Dictionary(type: "procedure", [
                "description": def.description.map(LexValue.string),
                "parameters": def.parameters?.lexValue,
                "input": def.input?.lexValue,
                "output": def.output?.lexValue,
                "errors": def.errors.map { .array($0.map(\.lexValue)) },
            ]))
        case let .subscription(def):
            var message: [String: LexValue] = ["schema": def.message.schema.lexValue]
            message["description"] = def.message.description.map(LexValue.string)
            return .object(Dictionary(type: "subscription", [
                "description": def.description.map(LexValue.string),
                "parameters": def.parameters?.lexValue,
                "message": .object(message),
                "errors": def.errors.map { .array($0.map(\.lexValue)) },
            ]))
        case let .permissionSet(def):
            return .object(Dictionary(type: "permission-set", [
                "description": def.description.map(LexValue.string),
                "title": def.title.map(LexValue.string),
                "title:lang": def.titleLang.map { .object($0.mapValues(LexValue.string)) },
                "detail": def.detail.map(LexValue.string),
                "detail:lang": def.detailLang.map { .object($0.mapValues(LexValue.string)) },
                "permissions": .array(def.permissions.map(\.lexValue)),
            ]))
        case let .object(def):
            return def.lexValue
        case let .params(def):
            return def.lexValue
        case let .permission(def):
            return def.lexValue
        case let .array(def):
            return .object(Dictionary(type: "array", [
                "description": def.description.map(LexValue.string),
                "items": def.items.lexValue,
                "minLength": lexCount(def.minLength),
                "maxLength": lexCount(def.maxLength),
            ]))
        case let .token(def):
            return .object(Dictionary(type: "token", ["description": def.description.map(LexValue.string)]))
        case let .string(def):
            return .object(Dictionary(type: "string", [
                "description": def.description.map(LexValue.string),
                "format": def.format.map { .string($0.rawValue) },
                "minLength": lexCount(def.minLength),
                "maxLength": lexCount(def.maxLength),
                "minGraphemes": lexCount(def.minGraphemes),
                "maxGraphemes": lexCount(def.maxGraphemes),
                "knownValues": lexStrings(def.knownValues),
                "enum": lexStrings(def.enumValues),
                "default": def.defaultValue.map(LexValue.string),
                "const": def.constValue.map(LexValue.string),
            ]))
        case let .integer(def):
            return .object(Dictionary(type: "integer", [
                "description": def.description.map(LexValue.string),
                "minimum": def.minimum.map(LexValue.integer),
                "maximum": def.maximum.map(LexValue.integer),
                "enum": def.enumValues.map { .array($0.map(LexValue.integer)) },
                "default": def.defaultValue.map(LexValue.integer),
                "const": def.constValue.map(LexValue.integer),
            ]))
        case let .boolean(def):
            return .object(Dictionary(type: "boolean", [
                "description": def.description.map(LexValue.string),
                "default": def.defaultValue.map(LexValue.boolean),
                "const": def.constValue.map(LexValue.boolean),
            ]))
        case let .bytes(def):
            return .object(Dictionary(type: "bytes", [
                "description": def.description.map(LexValue.string),
                "minLength": lexCount(def.minLength),
                "maxLength": lexCount(def.maxLength),
            ]))
        case let .cidLink(def):
            return .object(Dictionary(type: "cid-link", ["description": def.description.map(LexValue.string)]))
        case let .blob(def):
            return .object(Dictionary(type: "blob", [
                "description": def.description.map(LexValue.string),
                "accept": lexStrings(def.accept),
                "maxSize": def.maxSize.map(LexValue.integer),
            ]))
        case let .unknown(def):
            return .object(Dictionary(type: "unknown", ["description": def.description.map(LexValue.string)]))
        case let .ref(def):
            return .object(Dictionary(type: "ref", [
                "description": def.description.map(LexValue.string),
                "ref": .string(def.ref),
            ]))
        case let .union(def):
            return .object(Dictionary(type: "union", [
                "description": def.description.map(LexValue.string),
                "refs": lexStrings(def.refs),
                "closed": def.closed.map(LexValue.boolean),
            ]))
        case let .unsupported(def):
            return def.raw
        }
    }
}

extension LexObject {
    var lexValue: LexValue {
        .object(Dictionary(type: "object", [
            "description": description.map(LexValue.string),
            "properties": .object(properties.mapValues(\.lexValue)),
            "required": lexStrings(required),
            "nullable": lexStrings(nullable),
        ]))
    }
}

extension LexParams {
    var lexValue: LexValue {
        .object(Dictionary(type: "params", [
            "description": description.map(LexValue.string),
            "properties": .object(properties.mapValues(\.lexValue)),
            "required": lexStrings(required),
        ]))
    }
}

extension LexPermission {
    var lexValue: LexValue {
        var fields = parameters
        fields["type"] = .string("permission")
        fields["resource"] = .string(resource)
        return .object(fields)
    }
}

extension LexXRPCBody {
    var lexValue: LexValue {
        var fields: [String: LexValue] = ["encoding": .string(encoding)]
        fields["description"] = description.map(LexValue.string)
        fields["schema"] = schema?.lexValue
        return .object(fields)
    }
}

extension LexXRPCError {
    var lexValue: LexValue {
        var fields: [String: LexValue] = ["name": .string(name)]
        fields["description"] = description.map(LexValue.string)
        return .object(fields)
    }
}
