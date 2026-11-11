import Foundation

/// Walks a value and a schema together, collecting every issue.
///
/// The walk is iterative: pending work is kept on an explicit stack rather
/// than the call stack, so the depth of the data (which a remote party
/// controls) can not overflow the thread's stack. Work is pushed in reverse
/// and popped in order, which reports issues depth-first in document order.
struct LexiconDataValidator {
    let catalog: LexiconCatalog
    let options: LexiconValidationOptions
    private(set) var issues: [LexiconValidationIssue] = []
    private var stack: [Work] = []

    /// One pending step.
    private enum Work {
        /// Validate `value` against `def`, which lives in document `base`.
        case validate(LexValue, LexiconDef, base: String, path: String, depth: Int)
        /// Validate `value` against an object schema.
        case object(LexValue, LexObject, base: String, path: String, depth: Int)
        /// Validate the elements of an array from `index` on, one per step,
        /// so a long array never occupies more than one slot of the stack.
        case items([LexValue], LexiconDef, base: String, path: String, depth: Int, index: Int)
        /// Report an issue that was found earlier but belongs after the
        /// steps queued before it.
        case issue(LexiconValidationIssue)
    }

    init(catalog: LexiconCatalog, options: LexiconValidationOptions) {
        self.catalog = catalog
        self.options = options
    }

    private var isFull: Bool {
        issues.count >= options.maximumIssues
    }

    mutating func report(_ code: LexiconValidationIssue.Code, _ path: String, _ message: String) {
        guard !isFull else { return }
        issues.append(LexiconValidationIssue(path: path, code: code, message: message))
    }

    private mutating func mismatch(_ expected: String, _ value: LexValue, _ path: String) {
        report(.typeMismatch, path, "must be \(expected), found \(value.kind)")
    }

    /// Throws the collected issues, if any.
    func finish() throws {
        if let error = LexiconValidationError(issues: issues) {
            throw error
        }
    }

    // MARK: Entry points

    /// Validates `value` against `def`.
    ///
    /// - Parameter base: NSID of the document `def` lives in, used to resolve
    ///   `#local` references.
    mutating func validate(_ value: LexValue, _ def: LexiconDef, base: String, path: String) {
        stack.append(.validate(value, def, base: base, path: path, depth: 0))
        drain()
    }

    /// Validates `value` against an object schema.
    mutating func validateObject(_ value: LexValue, _ object: LexObject, base: String, path: String) {
        stack.append(.object(value, object, base: base, path: path, depth: 0))
        drain()
    }

    /// Validates an XRPC body or subscription message schema, which must
    /// describe an object.
    mutating func validateBody(_ value: LexValue, _ schema: LexiconDef, base: String, explicitType: String? = nil) {
        if value.isNull {
            report(.nullNotAllowed, "", "must not be null")
            return
        }
        switch schema {
        case let .object(object):
            stack.append(.object(value, object, base: base, path: "", depth: 0))
        case let .ref(ref):
            stepRef(value, ref.ref, base: base, path: "", depth: 0, mustBeObject: true)
        case let .union(union):
            stepUnion(value, union, base: base, path: "", depth: 0, explicitType: explicitType)
        default:
            report(.unsupportedSchemaType, "", "a body schema must be an object, a ref or a union, not \"\(schema.typeName)\"")
        }
        drain()
    }

    private mutating func drain() {
        while let work = stack.popLast() {
            guard !isFull else {
                stack.removeAll()
                return
            }
            switch work {
            case let .validate(value, def, base, path, depth):
                step(value, def, base: base, path: path, depth: depth)
            case let .object(value, object, base, path, depth):
                stepObject(value, object, base: base, path: path, depth: depth)
            case let .items(items, def, base, path, depth, index):
                if index + 1 < items.count {
                    stack.append(.items(items, def, base: base, path: path, depth: depth, index: index + 1))
                }
                step(items[index], def, base: base, path: LexPath.appending(path, index), depth: depth)
            case let .issue(issue):
                issues.append(issue)
            }
        }
    }

    /// Queues steps so that they run in the order given.
    private mutating func push(_ steps: [Work]) {
        stack.append(contentsOf: steps.reversed())
    }

    // MARK: Steps

    private mutating func step(_ value: LexValue, _ def: LexiconDef, base: String, path: String, depth: Int) {
        guard depth <= options.maximumDepth else {
            report(.depthLimitExceeded, path, "value nests deeper than \(options.maximumDepth)")
            return
        }
        if value.isNull {
            report(.nullNotAllowed, path, "must not be null")
            return
        }
        switch def {
        case let .object(object):
            stepObject(value, object, base: base, path: path, depth: depth)
        case let .record(record):
            stepObject(value, record.record, base: base, path: path, depth: depth)
        case let .array(array):
            stepArray(value, array, base: base, path: path, depth: depth)
        case let .string(string):
            stepString(value, string, path: path)
        case let .integer(integer):
            stepInteger(value, integer, path: path)
        case let .boolean(boolean):
            guard let flag = value.boolValue else { return mismatch("a boolean", value, path) }
            if let constValue = boolean.constValue, flag != constValue {
                report(.valueNotConst, path, "must be \(constValue)")
            }
        case let .bytes(bytes):
            stepBytes(value, bytes, path: path)
        case .cidLink:
            guard value.cidValue != nil else { return mismatch("a CID link", value, path) }
        case let .blob(blob):
            stepBlob(value, blob, path: path)
        case .unknown:
            // Any object, but not one of the compound data-model types.
            guard case .object = value, value.blobRef == nil else {
                return mismatch("a plain object", value, path)
            }
        case let .ref(ref):
            stepRef(value, ref.ref, base: base, path: path, depth: depth, mustBeObject: false)
        case let .union(union):
            stepUnion(value, union, base: base, path: path, depth: depth, explicitType: nil)
        case .token:
            report(.tokenIsNotData, path, "a token has no data representation")
        case .query, .procedure, .subscription, .permissionSet, .params, .permission, .unsupported:
            report(.unsupportedSchemaType, path, "a \"\(def.typeName)\" definition does not describe a data value")
        }
    }

    private mutating func stepString(_ value: LexValue, _ string: LexString, path: String) {
        guard let text = value.stringValue else { return mismatch("a string", value, path) }
        for violation in string.violations(of: text) {
            report(violation.code, path, violation.message)
        }
    }

    private mutating func stepInteger(_ value: LexValue, _ integer: LexInteger, path: String) {
        guard let number = value.integerValue else { return mismatch("an integer", value, path) }
        for violation in integer.violations(of: number) {
            report(violation.code, path, violation.message)
        }
    }

    private mutating func stepBytes(_ value: LexValue, _ bytes: LexBytes, path: String) {
        guard let data = value.bytesValue else { return mismatch("bytes", value, path) }
        if let minLength = bytes.minLength, data.count < minLength {
            report(.bytesTooShort, path, "must not be smaller than \(minLength) bytes (is \(data.count))")
        }
        if let maxLength = bytes.maxLength, data.count > maxLength {
            report(.bytesTooLong, path, "must not be larger than \(maxLength) bytes (is \(data.count))")
        }
    }

    private mutating func stepObject(_ value: LexValue, _ object: LexObject, base: String, path: String, depth: Int) {
        guard depth <= options.maximumDepth else {
            report(.depthLimitExceeded, path, "value nests deeper than \(options.maximumDepth)")
            return
        }
        guard case let .object(fields) = value, value.blobRef == nil else {
            return mismatch("an object", value, path)
        }
        let required = Set(object.required ?? [])
        let nullable = Set(object.nullable ?? [])
        var steps: [Work] = []
        // Sorted so the issue order is deterministic. Properties the schema
        // does not define are ignored, as the specification requires.
        for name in object.properties.keys.sorted() {
            guard let property = object.properties[name] else { continue }
            let propertyPath = LexPath.appending(path, name)
            guard let propertyValue = fields[name] else {
                if required.contains(name) {
                    steps.append(.issue(LexiconValidationIssue(
                        path: propertyPath,
                        code: .missingRequiredProperty,
                        message: "required property \"\(name)\" is missing"
                    )))
                }
                continue
            }
            if propertyValue.isNull {
                if !nullable.contains(name) {
                    steps.append(.issue(LexiconValidationIssue(
                        path: propertyPath,
                        code: .nullNotAllowed,
                        message: "property \"\(name)\" is not nullable"
                    )))
                }
                continue
            }
            steps.append(.validate(propertyValue, property, base: base, path: propertyPath, depth: depth + 1))
        }
        push(steps)
    }

    private mutating func stepArray(_ value: LexValue, _ array: LexArray, base: String, path: String, depth: Int) {
        guard case let .array(items) = value else {
            return mismatch("an array", value, path)
        }
        if let minLength = array.minLength, items.count < minLength {
            report(.arrayTooShort, path, "must not have fewer than \(minLength) elements (has \(items.count))")
        }
        if let maxLength = array.maxLength, items.count > maxLength {
            report(.arrayTooLong, path, "must not have more than \(maxLength) elements (has \(items.count))")
        }
        if !items.isEmpty {
            stack.append(.items(items, array.items, base: base, path: path, depth: depth + 1, index: 0))
        }
    }

    private mutating func stepBlob(_ value: LexValue, _ blob: LexBlob, path: String) {
        guard case let .object(fields) = value else {
            return mismatch("a blob", value, path)
        }
        let reference: LexBlobRef
        do {
            reference = try LexBlobRef(typedFields: fields)
        } catch {
            guard options.allowLegacyBlobs, let legacy = LexBlobRef(legacyFields: fields) else {
                let detail = (error as? LexValueError)?.message ?? "not a blob reference"
                report(.blobMalformed, path, "must be a blob reference: \(detail)")
                return
            }
            reference = legacy
        }
        if options.requireRawBlobCIDs, !reference.hasRawCodec {
            report(.blobMalformed, LexPath.appending(path, reference.isLegacy ? "cid" : "ref"), "blob reference must use the raw codec")
        }
        if !blob.accepts(mimeType: reference.mimeType) {
            report(
                .blobTypeNotAccepted,
                LexPath.appending(path, "mimeType"),
                "MIME type \"\(reference.mimeType)\" is not accepted (accepts \((blob.accept ?? []).joined(separator: ", ")))"
            )
        }
        if let maxSize = blob.maxSize, let size = reference.size, size > maxSize {
            report(.blobTooLarge, LexPath.appending(path, "size"), "blob of \(size) bytes exceeds the maximum of \(maxSize)")
        }
    }

    // MARK: References

    private mutating func stepRef(_ value: LexValue, _ ref: String, base: String, path: String, depth: Int, mustBeObject: Bool) {
        guard let reference = LexiconReference(ref, relativeTo: base) else {
            report(.unresolvedReference, path, "the schema reference \"\(ref)\" is not valid")
            return
        }
        guard let target = catalog.definition(reference) else {
            report(.unresolvedReference, path, "the schema refers to \(reference), which is not in the catalog")
            return
        }
        if let problem = LexiconSchemaValidator.referenceTargetProblem(target, inUnion: false) {
            report(target.isToken ? .tokenIsNotData : .invalidReferenceTarget, path, "the schema reference \"\(ref)\" \(problem)")
            return
        }
        switch target {
        case let .record(record):
            // A reference to a record keeps the $type discriminator. The
            // discriminator is reported after the record's own properties.
            var steps: [Work] = [.object(value, record.record, base: reference.nsid, path: path, depth: depth)]
            if let issue = discriminatorIssue(value, expected: reference, path: path) {
                steps.append(.issue(issue))
            }
            push(steps)
        case let .object(object):
            stack.append(.object(value, object, base: reference.nsid, path: path, depth: depth))
        default:
            if mustBeObject {
                report(.invalidReferenceTarget, path, "the schema reference \"\(ref)\" must point at an object for a body, found \"\(target.typeName)\"")
                return
            }
            // A referenced definition can not itself be a ref or a union, so
            // this does not chain.
            stack.append(.validate(value, target, base: reference.nsid, path: path, depth: depth))
        }
    }

    /// The issue, if any, with an object's `$type` when it must be exactly the
    /// canonical name of `expected`.
    private func discriminatorIssue(_ value: LexValue, expected: LexiconReference, path: String) -> LexiconValidationIssue? {
        guard case let .object(fields) = value else { return nil }
        let typePath = LexPath.appending(path, "$type")
        guard let type = fields["$type"]?.stringValue else {
            return LexiconValidationIssue(path: typePath, code: .missingTypeDiscriminator, message: "must include \"$type\": \"\(expected)\"")
        }
        guard type == expected.description else {
            return LexiconValidationIssue(path: typePath, code: .invalidTypeDiscriminator, message: "$type must be \"\(expected)\", found \"\(type)\"")
        }
        return nil
    }

    /// Validates a union member.
    ///
    /// - Parameter explicitType: The variant named out of band (the `t` of an
    ///   event-stream frame header). When `nil` the value's own `$type` is the
    ///   discriminator and is required.
    private mutating func stepUnion(
        _ value: LexValue,
        _ union: LexUnion,
        base: String,
        path: String,
        depth: Int,
        explicitType: String?
    ) {
        guard case let .object(fields) = value, value.blobRef == nil else {
            return mismatch("an object with a \"$type\"", value, path)
        }
        let typePath = LexPath.appending(path, "$type")
        let discriminator: String
        if let explicitType {
            discriminator = explicitType
        } else {
            guard let type = fields["$type"]?.stringValue else {
                report(.missingTypeDiscriminator, typePath, "a union member must include a \"$type\"")
                return
            }
            if type.hasSuffix("#main") {
                report(.invalidTypeDiscriminator, typePath, "$type must not use the \"#main\" suffix; write \"\(type.dropLast(5))\"")
                return
            }
            discriminator = type
        }

        let variants = Set(union.refs.compactMap { LexiconReference($0, relativeTo: base) })
        // A frame header may name the variant relative to the subscription
        // ("#commit"); a $type in data is always absolute.
        let selected = LexiconReference(discriminator, relativeTo: explicitType == nil ? nil : base)
        guard let selected, variants.contains(selected) else {
            if union.isClosed {
                report(
                    .unionVariantNotAllowed,
                    explicitType == nil ? typePath : path,
                    "\"\(discriminator)\" is not one of the closed union's variants (\(union.refs.joined(separator: ", ")))"
                )
            }
            // An open union accepts variants this schema does not know.
            return
        }
        guard let target = catalog.definition(selected) else {
            report(.unresolvedReference, path, "the union variant \(selected) is not in the catalog")
            return
        }
        switch target {
        case let .object(object):
            stack.append(.object(value, object, base: selected.nsid, path: path, depth: depth))
        case let .record(record):
            stack.append(.object(value, record.record, base: selected.nsid, path: path, depth: depth))
        default:
            report(.invalidReferenceTarget, path, "the union variant \(selected) is a \"\(target.typeName)\"; variants must be objects or records")
        }
    }
}

extension LexiconDef {
    var isToken: Bool {
        if case .token = self { return true }
        return false
    }
}
