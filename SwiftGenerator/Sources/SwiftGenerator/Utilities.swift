import Foundation

/// Utility functions for code generation
enum SwiftUtilities {
    /// Swift reserved keywords that need backticks
    static let reservedKeywords: Set<String> = [
        "class", "struct", "enum", "protocol", "extension", "func", "var", "let",
        "import", "typealias", "return", "if", "else", "switch", "case", "default",
        "for", "while", "repeat", "break", "continue", "fallthrough", "guard",
        "where", "defer", "do", "catch", "throw", "throws", "rethrows", "try",
        "as", "is", "nil", "true", "false", "self", "Self", "super", "init",
        "deinit", "subscript", "operator", "inout", "associatedtype", "precedencegroup",
        "static", "public", "private", "internal", "fileprivate", "open", "final",
        "required", "optional", "lazy", "dynamic", "infix", "prefix", "postfix",
        "convenience", "override", "mutating", "nonmutating", "weak", "unowned",
        "indirect", "Type", "Protocol", "Any", "some"
    ]

    /// Sanitize a property name (add backticks if needed)
    static func sanitizePropertyName(_ name: String) -> String {
        if reservedKeywords.contains(name) {
            return "`\(name)`"
        }
        return name
    }

    /// Sanitize a type name (capitalize first letter, remove invalid chars)
    static func sanitizeTypeName(_ name: String) -> String {
        let cleaned = name.replacingOccurrences(of: "-", with: "_")
        return cleaned.uppercasedFirst()
    }

    /// Generate a safe enum case name from a type identifier
    static func safeEnumCaseName(from typeIdentifier: String) -> String {
        // Extract the last part of the identifier
        // e.g., "app.bsky.embed.images" -> "images"
        // e.g., "com.atproto.repo.strongRef" -> "strongRef"

        let parts = typeIdentifier.split(separator: ".")
        let lastPart = parts.last.map(String.init) ?? typeIdentifier

        // Split on '#' if present
        let defParts = lastPart.split(separator: "#")
        let defName = defParts.last.map(String.init) ?? lastPart

        // Convert to camelCase
        let camelCase = defName.toLowerCamelCase()

        // Handle reserved keywords
        if reservedKeywords.contains(camelCase) {
            return "\(camelCase)Type"
        }

        // Ensure it starts with a letter
        if camelCase.first?.isNumber ?? false {
            return "value\(camelCase.capitalized)"
        }

        return camelCase
    }

    /// Escape string for Swift code (handle quotes, newlines, etc.)
    static func escapeString(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }

    /// Generate documentation comment
    static func generateDocComment(_ description: String?, indent: String = "") -> String {
        guard let description = description, !description.isEmpty else {
            return ""
        }

        let lines = description.split(separator: "\n").map { line in
            "\(indent)/// \(line)"
        }.joined(separator: "\n")

        return lines + "\n"
    }

    /// Format parameter list for better readability
    static func formatParameters(_ params: [(name: String, type: String)]) -> String {
        guard !params.isEmpty else { return "" }

        if params.count == 1 {
            return "\(params[0].name): \(params[0].type)"
        }

        return params.map { param in
            "\n        \(param.name): \(param.type)"
        }.joined(separator: ",") + "\n    "
    }
}

extension String {
    /// Convert kebab-case or snake_case to PascalCase
    func toPascalCase() -> String {
        return self.split(whereSeparator: { $0 == "-" || $0 == "_" || $0 == "." })
            .map { String($0).uppercasedFirst() }
            .joined()
    }

    /// Convert to camelCase
    func toCamelCase() -> String {
        let pascal = toPascalCase()
        return pascal.lowercasedFirst()
    }

    /// Check if string is a valid Swift identifier
    var isValidSwiftIdentifier: Bool {
        guard !isEmpty else { return false }
        guard let first = first else { return false }

        // Must start with letter or underscore
        guard first.isLetter || first == "_" else { return false }

        // Rest must be letters, numbers, or underscores
        return allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }
}

/// Helper for building indented code
struct CodeBuilder {
    private var lines: [String] = []
    private var indentLevel: Int = 0
    private let indentSize: Int

    init(indentSize: Int = 4) {
        self.indentSize = indentSize
    }

    private var indent: String {
        String(repeating: " ", count: indentLevel * indentSize)
    }

    mutating func addLine(_ line: String = "") {
        if line.isEmpty {
            lines.append("")
        } else {
            lines.append(indent + line)
        }
    }

    mutating func addLines(_ multiline: String) {
        for line in multiline.split(separator: "\n", omittingEmptySubsequences: false) {
            addLine(String(line))
        }
    }

    mutating func increaseIndent() {
        indentLevel += 1
    }

    mutating func decreaseIndent() {
        indentLevel = max(0, indentLevel - 1)
    }

    mutating func withIndent(_ block: (inout CodeBuilder) -> Void) {
        increaseIndent()
        block(&self)
        decreaseIndent()
    }

    func build() -> String {
        lines.joined(separator: "\n")
    }
}
