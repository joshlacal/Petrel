import Foundation

struct TypeConverter {
    let lexiconID: String
    let allDefs: [String: LexiconDef]

    /// Convert a Lexicon property to a Swift type string
    func convertProperty(_ property: LexiconProperty, propertyName: String, isRequired: Bool) -> SwiftPropertyInfo {
        switch property {
        case .type(let lexType):
            return convertType(lexType, propertyName: propertyName, isRequired: isRequired)
        case .object(let obj):
            // Inline object - should be defined as nested type
            let typeName = propertyName.uppercasedFirst()
            return SwiftPropertyInfo(typeName: typeName, isOptional: !isRequired, needsBoxing: false)
        }
    }

    /// Convert a LexiconType to Swift type
    func convertType(_ lexType: LexiconType, propertyName: String, isRequired: Bool) -> SwiftPropertyInfo {
        let type = lexType.type
        let isOptional = !isRequired

        switch type {
        case "string":
            return convertStringType(lexType, isOptional: isOptional)
        case "integer":
            return SwiftPropertyInfo(typeName: "Int", isOptional: isOptional, needsBoxing: false)
        case "number", "float":
            return SwiftPropertyInfo(typeName: "Double", isOptional: isOptional, needsBoxing: false)
        case "boolean":
            return SwiftPropertyInfo(typeName: "Bool", isOptional: isOptional, needsBoxing: false)
        case "blob":
            return SwiftPropertyInfo(typeName: "Blob", isOptional: isOptional, needsBoxing: false)
        case "bytes":
            return SwiftPropertyInfo(typeName: "Bytes", isOptional: isOptional, needsBoxing: false)
        case "cid-link":
            return SwiftPropertyInfo(typeName: "CID", isOptional: isOptional, needsBoxing: false)
        case "array":
            return convertArrayType(lexType, isOptional: isOptional, propertyName: propertyName)
        case "ref":
            return convertRefType(lexType, isOptional: isOptional)
        case "union":
            return convertUnionType(lexType, isOptional: isOptional, propertyName: propertyName)
        case "object":
            return SwiftPropertyInfo(typeName: "[String: ATProtocolValueContainer]", isOptional: isOptional, needsBoxing: false)
        case "unknown":
            // Special case for didDoc
            if propertyName == "didDoc" {
                return SwiftPropertyInfo(typeName: "DIDDocument", isOptional: isOptional, needsBoxing: false)
            }
            return SwiftPropertyInfo(typeName: "ATProtocolValueContainer", isOptional: isOptional, needsBoxing: false)
        default:
            // Unknown type - use container
            return SwiftPropertyInfo(typeName: "ATProtocolValueContainer", isOptional: isOptional, needsBoxing: false)
        }
    }

    private func convertStringType(_ lexType: LexiconType, isOptional: Bool) -> SwiftPropertyInfo {
        guard let format = lexType.format else {
            // Check for known values (enum)
            if let knownValues = lexType.knownValues, !knownValues.isEmpty {
                // Will be generated as enum
                return SwiftPropertyInfo(typeName: "String", isOptional: isOptional, needsBoxing: false)
            }
            return SwiftPropertyInfo(typeName: "String", isOptional: isOptional, needsBoxing: false)
        }

        switch format {
        case "datetime":
            return SwiftPropertyInfo(typeName: "ATProtocolDate", isOptional: isOptional, needsBoxing: false)
        case "uri":
            return SwiftPropertyInfo(typeName: "URI", isOptional: isOptional, needsBoxing: false)
        case "at-uri":
            return SwiftPropertyInfo(typeName: "ATProtocolURI", isOptional: isOptional, needsBoxing: false)
        case "at-identifier":
            return SwiftPropertyInfo(typeName: "ATIdentifier", isOptional: isOptional, needsBoxing: false)
        case "cid":
            return SwiftPropertyInfo(typeName: "CID", isOptional: isOptional, needsBoxing: false)
        case "did":
            return SwiftPropertyInfo(typeName: "DID", isOptional: isOptional, needsBoxing: false)
        case "handle":
            return SwiftPropertyInfo(typeName: "Handle", isOptional: isOptional, needsBoxing: false)
        case "nsid":
            return SwiftPropertyInfo(typeName: "String", isOptional: isOptional, needsBoxing: false)
        case "tid":
            return SwiftPropertyInfo(typeName: "TID", isOptional: isOptional, needsBoxing: false)
        case "record-key":
            return SwiftPropertyInfo(typeName: "String", isOptional: isOptional, needsBoxing: false)
        case "language":
            return SwiftPropertyInfo(typeName: "LanguageCodeContainer", isOptional: isOptional, needsBoxing: false)
        default:
            return SwiftPropertyInfo(typeName: "String", isOptional: isOptional, needsBoxing: false)
        }
    }

    private func convertArrayType(_ lexType: LexiconType, isOptional: Bool, propertyName: String) -> SwiftPropertyInfo {
        guard let items = lexType.items else {
            return SwiftPropertyInfo(typeName: "[ATProtocolValueContainer]", isOptional: isOptional, needsBoxing: false)
        }

        let itemInfo = convertType(items.value, propertyName: propertyName, isRequired: true)
        return SwiftPropertyInfo(typeName: "[\(itemInfo.typeName)]", isOptional: isOptional, needsBoxing: false)
    }

    private func convertRefType(_ lexType: LexiconType, isOptional: Bool) -> SwiftPropertyInfo {
        guard let ref = lexType.ref else {
            return SwiftPropertyInfo(typeName: "ATProtocolValueContainer", isOptional: isOptional, needsBoxing: false)
        }

        let swiftType = convertRefToSwiftType(ref)
        return SwiftPropertyInfo(typeName: swiftType, isOptional: isOptional, needsBoxing: false)
    }

    private func convertUnionType(_ lexType: LexiconType, isOptional: Bool, propertyName: String) -> SwiftPropertyInfo {
        // Union types are generated as enums with a specific naming pattern
        let baseName = lexiconID.split(separator: ".").map { $0.uppercasedFirst() }.joined()
        let unionName = baseName + propertyName.uppercasedFirst() + "Union"
        return SwiftPropertyInfo(typeName: unionName, isOptional: isOptional, needsBoxing: false)
    }

    /// Convert a ref string to Swift type name
    /// Examples:
    /// - "app.bsky.actor.defs#profileView" -> "AppBskyActorDefs.ProfileView"
    /// - "#replyRef" -> "ReplyRef"
    func convertRefToSwiftType(_ ref: String) -> String {
        if ref.hasPrefix("#") {
            // Local reference
            return ref.dropFirst().uppercasedFirst()
        }

        // External reference
        let parts = ref.split(separator: "#")
        let lexiconPart = parts[0]
        let defPart = parts.count > 1 ? parts[1] : "main"

        let lexiconName = lexiconPart.split(separator: ".").map { $0.uppercasedFirst() }.joined()

        if defPart == "main" {
            return lexiconName
        } else {
            return "\(lexiconName).\(defPart.uppercasedFirst())"
        }
    }
}

struct SwiftPropertyInfo {
    let typeName: String
    let isOptional: Bool
    let needsBoxing: Bool

    var fullTypeName: String {
        if needsBoxing {
            return isOptional ? "IndirectBox<\(typeName)>?" : "IndirectBox<\(typeName)>"
        }
        return isOptional ? "\(typeName)?" : typeName
    }
}

extension String {
    func uppercasedFirst() -> String {
        guard !isEmpty else { return self }
        return prefix(1).uppercased() + dropFirst()
    }

    func lowercasedFirst() -> String {
        guard !isEmpty else { return self }
        return prefix(1).lowercased() + dropFirst()
    }

    /// Convert to upper camel case (PascalCase)
    func toUpperCamelCase() -> String {
        let words = self.split(separator: "-")
            .map { $0.split(separator: "_") }
            .flatMap { $0 }
            .map { String($0).uppercasedFirst() }
        return words.joined()
    }

    /// Convert to lower camel case
    func toLowerCamelCase() -> String {
        let upper = toUpperCamelCase()
        return upper.lowercasedFirst()
    }

    /// Sanitize for Swift enum case name
    func toEnumCase() -> String {
        // Remove special characters and convert to camel case
        let cleaned = self.replacing(charactersIn: CharacterSet.alphanumerics.inverted, with: " ")
        let words = cleaned.split(separator: " ").map { String($0) }

        if words.isEmpty {
            return "case_\(self.hashValue)"
        }

        // If starts with number, prefix with underscore
        var result = words.map { $0.lowercased() }.joined(separator: "_")
        if result.first?.isNumber ?? false {
            result = "_" + result
        }

        return result
    }

    func replacing(charactersIn set: CharacterSet, with replacement: String) -> String {
        let components = self.components(separatedBy: set)
        return components.joined(separator: replacement)
    }
}
