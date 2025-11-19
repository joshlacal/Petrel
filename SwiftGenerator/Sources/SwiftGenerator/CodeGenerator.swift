import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftParser

/// Generates Swift code from a single Lexicon file
class CodeGenerator {
    let lexicon: Lexicon
    let cycleDetector: CycleDetector
    let typeConverter: TypeConverter

    private var generatedUnions: Set<String> = []

    init(lexicon: Lexicon, cycleDetector: CycleDetector) {
        self.lexicon = lexicon
        self.cycleDetector = cycleDetector
        self.typeConverter = TypeConverter(lexiconID: lexicon.id, allDefs: lexicon.defs)
    }

    /// Generate complete Swift file content
    func generate() -> String {
        let mainDef = lexicon.defs["main"]

        guard let mainDef = mainDef else {
            return generateEmptyFile()
        }

        var declarations: [DeclSyntax] = []

        // Add header comment
        let header = """
        import Foundation

        // lexicon: \(lexicon.lexicon), id: \(lexicon.id)

        """

        let mainType = mainDef.type

        switch mainType {
        case "object", "record":
            declarations.append(generateStructDecl(name: getMainTypeName(), def: mainDef, isMain: true))
        case "query":
            declarations.append(generateQueryEnum())
        case "procedure":
            declarations.append(generateProcedureEnum())
        case "subscription":
            declarations.append(generateSubscriptionEnum())
        default:
            break
        }

        // Generate nested definitions
        for (defName, def) in lexicon.defs where defName != "main" {
            if let decl = generateNestedDef(name: defName, def: def) {
                declarations.append(decl)
            }
        }

        // Generate extension for query/procedure
        if mainType == "query" || mainType == "procedure" || mainType == "subscription" {
            if let extensionDecl = generateClientExtension(mainDef: mainDef) {
                declarations.append(extensionDecl)
            }
        }

        let sourceFile = SourceFileSyntax(
            statements: CodeBlockItemListSyntax(
                declarations.map { CodeBlockItemSyntax(item: .decl($0)) }
            )
        )

        return header + sourceFile.formatted().description
    }

    private func generateEmptyFile() -> String {
        return """
        import Foundation

        // lexicon: \(lexicon.lexicon), id: \(lexicon.id)
        // No main definition found
        """
    }

    private func getMainTypeName() -> String {
        return lexicon.id.split(separator: ".").map { $0.capitalized }.joined()
    }

    private func getNamespace() -> [String] {
        let parts = lexicon.id.split(separator: ".")
        return Array(parts.prefix(3)).map { $0.capitalized }
    }

    // MARK: - Struct Generation

    private func generateStructDecl(name: String, def: LexiconDef, isMain: Bool) -> DeclSyntax {
        let structName = name
        let properties = getProperties(from: def)
        let required = getRequired(from: def)

        var members: [MemberBlockItemSyntax] = []

        // Type identifier
        if isMain {
            let typeIdentifier = """
            public static let typeIdentifier = "\(lexicon.id)"
            """
            members.append(MemberBlockItemSyntax(decl: DeclSyntax(stringLiteral: typeIdentifier)))
        }

        // Properties
        for (propName, propDef) in properties.sorted(by: { $0.key < $1.key }) {
            let isRequired = required.contains(propName)
            let propertyDecl = generateProperty(name: propName, property: propDef, isRequired: isRequired)
            members.append(MemberBlockItemSyntax(decl: propertyDecl))
        }

        // Initializer
        members.append(MemberBlockItemSyntax(decl: generateInitializer(properties: properties, required: required)))

        // Codable initializer
        members.append(MemberBlockItemSyntax(decl: generateCodableInit(properties: properties, required: required)))

        // Encode method
        members.append(MemberBlockItemSyntax(decl: generateEncodeMethod(properties: properties, isMain: isMain)))

        // Equality
        members.append(MemberBlockItemSyntax(decl: generateEquality()))

        // isEqual method
        members.append(MemberBlockItemSyntax(decl: generateIsEqualMethod(properties: properties)))

        // Hash method
        members.append(MemberBlockItemSyntax(decl: generateHashMethod(properties: properties)))

        // toCBORValue method
        members.append(MemberBlockItemSyntax(decl: generateToCBORMethod(properties: properties, isMain: isMain)))

        // CodingKeys
        members.append(MemberBlockItemSyntax(decl: generateCodingKeys(properties: properties, isMain: isMain)))

        let conformances = isMain || name != getMainTypeName()
            ? ": ATProtocolCodable, ATProtocolValue"
            : ": ATProtocolCodable, ATProtocolValue"

        let structDecl = """
        public struct \(structName)\(conformances) {
            \(members.map { $0.description }.joined(separator: "\n\n    "))
        }
        """

        return DeclSyntax(stringLiteral: structDecl)
    }

    private func getProperties(from def: LexiconDef) -> [String: LexiconProperty] {
        if let properties = def.properties {
            return properties
        }
        if let record = def.record, let properties = record.properties {
            return properties
        }
        return [:]
    }

    private func getRequired(from def: LexiconDef) -> Set<String> {
        if let required = def.required {
            return Set(required)
        }
        if let record = def.record, let required = record.required {
            return Set(required)
        }
        return []
    }

    private func generateProperty(name: String, property: LexiconProperty, isRequired: Bool) -> DeclSyntax {
        let propertyInfo = typeConverter.convertProperty(property, propertyName: name, isRequired: isRequired)

        let decl = "public let \(name): \(propertyInfo.fullTypeName)"
        return DeclSyntax(stringLiteral: decl)
    }

    private func generateInitializer(properties: [String: LexiconProperty], required: Set<String>) -> DeclSyntax {
        let params = properties.sorted(by: { $0.key < $1.key }).map { propName, propDef in
            let isRequired = required.contains(propName)
            let propInfo = typeConverter.convertProperty(propDef, propertyName: propName, isRequired: isRequired)
            return "\(propName): \(propInfo.fullTypeName)"
        }.joined(separator: ", ")

        let assignments = properties.sorted(by: { $0.key < $1.key }).map { propName, _ in
            "self.\(propName) = \(propName)"
        }.joined(separator: "\n        ")

        let initializer = """
        // Standard initializer
        public init(
            \(params)
        ) {
            \(assignments)
        }
        """

        return DeclSyntax(stringLiteral: initializer)
    }

    private func generateCodableInit(properties: [String: LexiconProperty], required: Set<String>) -> DeclSyntax {
        let decodings = properties.sorted(by: { $0.key < $1.key }).map { propName, propDef in
            let isRequired = required.contains(propName)
            let propInfo = typeConverter.convertProperty(propDef, propertyName: propName, isRequired: isRequired)

            if isRequired {
                return """
                do {
                    \(propName) = try container.decode(\(propInfo.typeName).self, forKey: .\(propName))
                } catch {
                    LogManager.logError("Decoding error for required property '\(propName)': \\(error)")
                    throw error
                }
                """
            } else {
                return "\(propName) = try container.decodeIfPresent(\(propInfo.typeName).self, forKey: .\(propName))"
            }
        }.joined(separator: "\n\n        ")

        let initializer = """
        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            \(decodings)
        }
        """

        return DeclSyntax(stringLiteral: initializer)
    }

    private func generateEncodeMethod(properties: [String: LexiconProperty], isMain: Bool) -> DeclSyntax {
        var encodings: [String] = []

        if isMain {
            encodings.append("try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)")
        }

        for (propName, propDef) in properties.sorted(by: { $0.key < $1.key }) {
            let isRequired = getRequired(from: lexicon.defs["main"]!).contains(propName)
            if isRequired {
                encodings.append("try container.encode(\(propName), forKey: .\(propName))")
            } else {
                encodings.append("try container.encodeIfPresent(\(propName), forKey: .\(propName))")
            }
        }

        let method = """
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            \(encodings.joined(separator: "\n        "))
        }
        """

        return DeclSyntax(stringLiteral: method)
    }

    private func generateEquality() -> DeclSyntax {
        let method = """
        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }
        """
        return DeclSyntax(stringLiteral: method)
    }

    private func generateIsEqualMethod(properties: [String: LexiconProperty]) -> DeclSyntax {
        let comparisons = properties.sorted(by: { $0.key < $1.key }).map { propName, _ in
            """
            if \(propName) != other.\(propName) {
                return false
            }
            """
        }.joined(separator: "\n\n        ")

        let method = """
        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            \(comparisons)

            return true
        }
        """

        return DeclSyntax(stringLiteral: method)
    }

    private func generateHashMethod(properties: [String: LexiconProperty]) -> DeclSyntax {
        let combines = properties.sorted(by: { $0.key < $1.key }).map { propName, propDef in
            let isRequired = getRequired(from: lexicon.defs["main"] ?? LexiconDef(type: "", description: nil, key: nil, record: nil, parameters: nil, input: nil, output: nil, errors: nil, required: nil, nullable: nil, properties: nil, message: nil, items: nil, minLength: nil, maxLength: nil, format: nil, knownValues: nil, enum: nil, const: nil, maxGraphemes: nil, minGraphemes: nil, minimum: nil, maximum: nil, refs: nil, ref: nil)).contains(propName)

            if isRequired {
                return "hasher.combine(\(propName))"
            } else {
                return """
                if let value = \(propName) {
                    hasher.combine(value)
                } else {
                    hasher.combine(nil as Int?)
                }
                """
            }
        }.joined(separator: "\n        ")

        let method = """
        public func hash(into hasher: inout Hasher) {
            \(combines)
        }
        """

        return DeclSyntax(stringLiteral: method)
    }

    private func generateToCBORMethod(properties: [String: LexiconProperty], isMain: Bool) -> DeclSyntax {
        var adds: [String] = []

        if isMain {
            adds.append("map = map.adding(key: \"$type\", value: Self.typeIdentifier)")
        }

        for (propName, _) in properties.sorted(by: { $0.key < $1.key }) {
            let isRequired = getRequired(from: lexicon.defs["main"] ?? LexiconDef(type: "", description: nil, key: nil, record: nil, parameters: nil, input: nil, output: nil, errors: nil, required: nil, nullable: nil, properties: nil, message: nil, items: nil, minLength: nil, maxLength: nil, format: nil, knownValues: nil, enum: nil, const: nil, maxGraphemes: nil, minGraphemes: nil, minimum: nil, maximum: nil, refs: nil, ref: nil)).contains(propName)

            if isRequired {
                adds.append("""
                let \(propName)Value = try \(propName).toCBORValue()
                map = map.adding(key: "\(propName)", value: \(propName)Value)
                """)
            } else {
                adds.append("""
                if let value = \(propName) {
                    let \(propName)Value = try value.toCBORValue()
                    map = map.adding(key: "\(propName)", value: \(propName)Value)
                }
                """)
            }
        }

        let method = """
        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            \(adds.joined(separator: "\n\n        "))

            return map
        }
        """

        return DeclSyntax(stringLiteral: method)
    }

    private func generateCodingKeys(properties: [String: LexiconProperty], isMain: Bool) -> DeclSyntax {
        var cases: [String] = []

        if isMain {
            cases.append("case typeIdentifier = \"$type\"")
        }

        for propName in properties.keys.sorted() {
            cases.append("case \(propName)")
        }

        let enumDecl = """
        private enum CodingKeys: String, CodingKey {
            \(cases.joined(separator: "\n        "))
        }
        """

        return DeclSyntax(stringLiteral: enumDecl)
    }

    // MARK: - Enum Generation (for queries/procedures)

    private func generateQueryEnum() -> DeclSyntax {
        let typeName = getMainTypeName()
        let mainDef = lexicon.defs["main"]!

        var members: [String] = []

        // Parameters
        if let parameters = mainDef.parameters, let properties = parameters.properties {
            let paramsStruct = generateParametersStruct(properties: properties, required: Set(parameters.required ?? []))
            members.append(paramsStruct)
        }

        // Output
        if let output = mainDef.output {
            let outputType = generateOutputType(output: output)
            members.append(outputType)
        }

        let enumDecl = """
        public enum \(typeName) {
            public static let typeIdentifier = "\(lexicon.id)"
            \(members.joined(separator: "\n\n    "))
        }
        """

        return DeclSyntax(stringLiteral: enumDecl)
    }

    private func generateProcedureEnum() -> DeclSyntax {
        let typeName = getMainTypeName()
        let mainDef = lexicon.defs["main"]!

        var members: [String] = []

        // Input
        if let input = mainDef.input, let schema = input.schema {
            let inputStruct = generateInputStruct(schema: schema, properties: schema.properties ?? [:], required: Set(schema.required ?? []))
            members.append(inputStruct)
        }

        // Output
        if let output = mainDef.output {
            let outputType = generateOutputType(output: output)
            members.append(outputType)
        }

        let enumDecl = """
        public enum \(typeName) {
            public static let typeIdentifier = "\(lexicon.id)"
            \(members.joined(separator: "\n\n    "))
        }
        """

        return DeclSyntax(stringLiteral: enumDecl)
    }

    private func generateSubscriptionEnum() -> DeclSyntax {
        let typeName = getMainTypeName()
        let mainDef = lexicon.defs["main"]!

        var members: [String] = []

        // Parameters
        if let parameters = mainDef.parameters, let properties = parameters.properties {
            let paramsStruct = generateParametersStruct(properties: properties, required: Set(parameters.required ?? []))
            members.append(paramsStruct)
        }

        // Message type (if any)
        if let message = mainDef.message, let schema = message.schema {
            // Generate message union or type
            members.append("// Message schema would go here")
        }

        let enumDecl = """
        public enum \(typeName) {
            public static let typeIdentifier = "\(lexicon.id)"
            \(members.joined(separator: "\n\n    "))
        }
        """

        return DeclSyntax(stringLiteral: enumDecl)
    }

    private func generateParametersStruct(properties: [String: LexiconProperty], required: Set<String>) -> String {
        let props = properties.sorted(by: { $0.key < $1.key }).map { propName, propDef in
            let isRequired = required.contains(propName)
            let propInfo = typeConverter.convertProperty(propDef, propertyName: propName, isRequired: isRequired)
            return "public let \(propName): \(propInfo.fullTypeName)"
        }.joined(separator: "\n        ")

        return """
        public struct Parameters: Parametrizable {
            \(props)
        }
        """
    }

    private func generateInputStruct(schema: LexiconType, properties: [String: LexiconProperty], required: Set<String>) -> String {
        let props = properties.sorted(by: { $0.key < $1.key }).map { propName, propDef in
            let isRequired = required.contains(propName)
            let propInfo = typeConverter.convertProperty(propDef, propertyName: propName, isRequired: isRequired)
            return "public let \(propName): \(propInfo.fullTypeName)"
        }.joined(separator: "\n        ")

        return """
        public struct Input: ATProtocolCodable {
            \(props)
        }
        """
    }

    private func generateOutputType(output: LexiconBody) -> String {
        guard let schema = output.schema else {
            return "// No output schema"
        }

        // Check if it's a ref (typealias)
        if schema.type == "ref", let ref = schema.ref {
            let swiftType = typeConverter.convertRefToSwiftType(ref)
            return "public typealias Output = \(swiftType)"
        }

        // Binary data
        if output.encoding != "application/json" {
            return """
            public struct Output: ATProtocolCodable {
                public let data: Data
            }
            """
        }

        // Regular output struct
        if let properties = schema.properties {
            let required = Set(schema.required ?? [])
            let props = properties.sorted(by: { $0.key < $1.key }).map { propName, propDef in
                let isRequired = required.contains(propName)
                let propInfo = typeConverter.convertProperty(propDef, propertyName: propName, isRequired: isRequired)
                return "public let \(propName): \(propInfo.fullTypeName)"
            }.joined(separator: "\n        ")

            return """
            public struct Output: ATProtocolCodable {
                \(props)
            }
            """
        }

        return "// Output type could not be determined"
    }

    // MARK: - Nested Definitions

    private func generateNestedDef(name: String, def: LexiconDef) -> DeclSyntax? {
        let typeName = name.split(separator: "-").map { $0.capitalized }.joined()

        switch def.type {
        case "object":
            return generateStructDecl(name: typeName, def: def, isMain: false)
        case "union":
            return generateUnionEnum(name: typeName, def: def)
        default:
            return nil
        }
    }

    private func generateUnionEnum(name: String, def: LexiconDef) -> DeclSyntax? {
        guard let refs = def.refs else { return nil }

        let enumName = name.capitalized

        let cases = refs.map { ref in
            let swiftType = typeConverter.convertRefToSwiftType(ref)
            let caseName = ref.split(separator: ".").last?.split(separator: "#").last?.lowercased() ?? "unknown"
            return "case \(caseName)(\(swiftType))"
        }.joined(separator: "\n    ")

        let enumDecl = """
        public enum \(enumName): Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
            \(cases)
            case unexpected(ATProtocolValueContainer)

            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let typeValue = try container.decode(String.self, forKey: .type)

                switch typeValue {
                \(refs.map { ref in
                    let swiftType = typeConverter.convertRefToSwiftType(ref)
                    let caseName = ref.split(separator: ".").last?.split(separator: "#").last?.lowercased() ?? "unknown"
                    let typeID = ref.hasPrefix("#") ? "\\(lexicon.id)\\(ref)" : ref
                    return """
                    case "\(typeID)":
                        let value = try \(swiftType)(from: decoder)
                        self = .\(caseName)(value)
                    """
                }.joined(separator: "\n            "))
                default:
                    let unknownValue = try ATProtocolValueContainer(from: decoder)
                    self = .unexpected(unknownValue)
                }
            }

            private enum CodingKeys: String, CodingKey {
                case type = "$type"
            }
        }
        """

        return DeclSyntax(stringLiteral: enumDecl)
    }

    // MARK: - Client Extension

    private func generateClientExtension(mainDef: LexiconDef) -> DeclSyntax? {
        let namespace = getNamespace()
        let extensionPath = "ATProtoClient." + namespace.joined(separator: ".")
        let typeName = getMainTypeName()
        let functionName = lexicon.id.split(separator: ".").last?.lowercased() ?? "unknown"

        switch mainDef.type {
        case "query":
            return generateQueryFunction(extensionPath: extensionPath, typeName: typeName, functionName: functionName, mainDef: mainDef)
        case "procedure":
            return generateProcedureFunction(extensionPath: extensionPath, typeName: typeName, functionName: functionName, mainDef: mainDef)
        default:
            return nil
        }
    }

    private func generateQueryFunction(extensionPath: String, typeName: String, functionName: String, mainDef: LexiconDef) -> DeclSyntax {
        let hasOutput = mainDef.output != nil
        let returnType = hasOutput ? "(responseCode: Int, data: \(typeName).Output?)" : "Int"

        let description = mainDef.description ?? "Query method for \(lexicon.id)"

        let function = """
        public extension \(extensionPath) {
            /// \(description)
            func \(functionName)(input: \(typeName).Parameters) async throws -> \(returnType) {
                let endpoint = "\(lexicon.id)"
                let queryItems = input.asQueryItems()

                let urlRequest = try await networkService.createURLRequest(
                    endpoint: endpoint,
                    method: "GET",
                    headers: ["Accept": "application/json"],
                    body: nil,
                    queryItems: queryItems
                )

                let serviceDID = await networkService.getServiceDID(for: "\(lexicon.id)")
                let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
                let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
                let responseCode = response.statusCode

                \(hasOutput ? generateQueryOutputHandling(typeName: typeName) : "return responseCode")
            }
        }
        """

        return DeclSyntax(stringLiteral: function)
    }

    private func generateQueryOutputHandling(typeName: String) -> String {
        return """
        if (200...299).contains(responseCode) {
            do {
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(\(typeName).Output.self, from: responseData)
                return (responseCode, decodedData)
            } catch {
                LogManager.logError("Failed to decode response: \\(error)")
                return (responseCode, nil)
            }
        } else {
            return (responseCode, nil)
        }
        """
    }

    private func generateProcedureFunction(extensionPath: String, typeName: String, functionName: String, mainDef: LexiconDef) -> DeclSyntax {
        let hasInput = mainDef.input != nil
        let hasOutput = mainDef.output != nil
        let inputParam = hasInput ? "input: \(typeName).Input" : ""
        let returnType = hasOutput ? "(responseCode: Int, data: \(typeName).Output?)" : "Int"

        let description = mainDef.description ?? "Procedure method for \(lexicon.id)"

        let function = """
        public extension \(extensionPath) {
            /// \(description)
            func \(functionName)(\(inputParam)) async throws -> \(returnType) {
                let endpoint = "\(lexicon.id)"

                \(hasInput ? "let requestData = try JSONEncoder().encode(input)" : "let requestData: Data? = nil")

                let urlRequest = try await networkService.createURLRequest(
                    endpoint: endpoint,
                    method: "POST",
                    headers: ["Content-Type": "application/json"],
                    body: requestData,
                    queryItems: nil
                )

                let serviceDID = await networkService.getServiceDID(for: "\(lexicon.id)")
                let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
                let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
                let responseCode = response.statusCode

                \(hasOutput ? generateProcedureOutputHandling(typeName: typeName) : "return responseCode")
            }
        }
        """

        return DeclSyntax(stringLiteral: function)
    }

    private func generateProcedureOutputHandling(typeName: String) -> String {
        return """
        if (200...299).contains(responseCode) {
            do {
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(\(typeName).Output.self, from: responseData)
                return (responseCode, decodedData)
            } catch {
                LogManager.logError("Failed to decode response: \\(error)")
                return (responseCode, nil)
            }
        } else {
            return (responseCode, nil)
        }
        """
    }
}
