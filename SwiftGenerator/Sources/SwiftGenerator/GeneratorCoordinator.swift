import Foundation

/// Coordinates the two-pass generation process
class GeneratorCoordinator {
    let lexiconsPath: String
    let outputPath: String

    private var lexicons: [Lexicon] = []
    private let cycleDetector = CycleDetector()

    init(lexiconsPath: String, outputPath: String) {
        self.lexiconsPath = lexiconsPath
        self.outputPath = outputPath
    }

    /// Run the full generation process
    func generate() async throws {
        print("Starting Swift code generation...")
        print("Lexicons path: \(lexiconsPath)")
        print("Output path: \(outputPath)")

        // Pass 1: Discover and load all lexicons
        try await discoverLexicons()

        // Pass 2: Detect cycles
        detectCycles()

        // Pass 3: Generate code
        try await generateCode()

        // Pass 4: Generate special files
        try await generateSpecialFiles()

        print("✓ Code generation complete!")
    }

    // MARK: - Pass 1: Discovery

    private func discoverLexicons() async throws {
        print("\n[Pass 1] Discovering lexicons...")

        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(atPath: lexiconsPath)

        var count = 0

        while let file = enumerator?.nextObject() as? String {
            guard file.hasSuffix(".json") else { continue }

            let fullPath = (lexiconsPath as NSString).appendingPathComponent(file)

            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: fullPath))
                let lexicon = try JSONDecoder().decode(Lexicon.self, from: data)

                // Filter out ozone lexicons
                if lexicon.id.contains("ozone") {
                    print("  Skipping ozone lexicon: \(lexicon.id)")
                    continue
                }

                lexicons.append(lexicon)
                count += 1

                if count % 10 == 0 {
                    print("  Loaded \(count) lexicons...")
                }
            } catch {
                print("  ⚠ Warning: Failed to decode \(file): \(error)")
            }
        }

        print("✓ Discovered \(lexicons.count) lexicons")
    }

    // MARK: - Pass 2: Cycle Detection

    private func detectCycles() {
        print("\n[Pass 2] Detecting circular dependencies...")

        // Register all types
        for lexicon in lexicons {
            cycleDetector.registerLexicon(lexicon)
        }

        // Detect cycles
        cycleDetector.detectCycles()

        print("✓ Cycle detection complete")
    }

    // MARK: - Pass 3: Code Generation

    private func generateCode() async throws {
        print("\n[Pass 3] Generating Swift code...")

        let fileManager = FileManager.default

        // Ensure output directory exists
        try fileManager.createDirectory(atPath: outputPath, withIntermediateDirectories: true)

        var successCount = 0
        var failureCount = 0

        for lexicon in lexicons {
            do {
                let generator = CodeGenerator(lexicon: lexicon, cycleDetector: cycleDetector)
                let code = generator.generate()

                let fileName = lexicon.id.split(separator: ".").map { $0.capitalized }.joined() + ".swift"
                let filePath = (outputPath as NSString).appendingPathComponent(fileName)

                try code.write(toFile: filePath, atomically: true, encoding: .utf8)

                successCount += 1

                if successCount % 10 == 0 {
                    print("  Generated \(successCount) files...")
                }
            } catch {
                print("  ⚠ Warning: Failed to generate \(lexicon.id): \(error)")
                failureCount += 1
            }
        }

        print("✓ Generated \(successCount) files (\(failureCount) failures)")
    }

    // MARK: - Pass 4: Special Files

    private func generateSpecialFiles() async throws {
        print("\n[Pass 4] Generating special files...")

        try generateATProtoClientMain()
        try generateATProtocolValueContainer()

        print("✓ Special files generated")
    }

    private func generateATProtoClientMain() throws {
        // Build namespace hierarchy
        var hierarchy: [String: Any] = [:]

        for lexicon in lexicons {
            guard let mainDef = lexicon.defs["main"] else { continue }
            guard ["query", "procedure", "subscription"].contains(mainDef.type) else { continue }

            let parts = lexicon.id.split(separator: ".")
            guard parts.count >= 3 else { continue }

            let namespace = Array(parts.prefix(3))

            var current = hierarchy
            for (index, part) in namespace.enumerated() {
                let key = String(part)
                if index == namespace.count - 1 {
                    // Leaf level
                    if current[key] == nil {
                        current[key] = [:]
                    }
                } else {
                    // Intermediate level
                    if current[key] == nil {
                        current[key] = [:]
                    }
                }
                if let next = current[key] as? [String: Any] {
                    current = next
                } else {
                    break
                }
            }
        }

        let code = generateNamespaceClasses(hierarchy: hierarchy)

        let content = """
        import Foundation

        // Auto-generated namespace hierarchy for ATProtoClient

        \(code)
        """

        let filePath = (outputPath as NSString).appendingPathComponent("ATProtoClientGeneratedMain.swift")
        try content.write(toFile: filePath, atomically: true, encoding: .utf8)
    }

    private func generateNamespaceClasses(hierarchy: [String: Any], level: Int = 0) -> String {
        var classes: [String] = []

        for (key, value) in hierarchy.sorted(by: { $0.key < $1.key }) {
            let className = key.capitalized

            if let subHierarchy = value as? [String: Any], !subHierarchy.isEmpty {
                let nestedClasses = generateNamespaceClasses(hierarchy: subHierarchy, level: level + 1)

                let indent = String(repeating: "    ", count: level)

                let classCode = """
                \(indent)public final class \(className): @unchecked Sendable {
                \(indent)    private let networkService: any NetworkService

                \(indent)    init(networkService: any NetworkService) {
                \(indent)        self.networkService = networkService
                \(indent)    }

                \(nestedClasses)
                \(indent)}
                """
                classes.append(classCode)
            } else {
                let indent = String(repeating: "    ", count: level)

                let classCode = """
                \(indent)public final class \(className): @unchecked Sendable {
                \(indent)    private let networkService: any NetworkService

                \(indent)    init(networkService: any NetworkService) {
                \(indent)        self.networkService = networkService
                \(indent)    }
                \(indent)}
                """
                classes.append(classCode)
            }
        }

        return classes.joined(separator: "\n\n")
    }

    private func generateATProtocolValueContainer() throws {
        // Generate type registry
        var registrations: [String] = []

        for lexicon in lexicons {
            for (defName, def) in lexicon.defs {
                guard ["object", "record"].contains(def.type) else { continue }

                let typeID = defName == "main" ? lexicon.id : "\(lexicon.id)#\(defName)"
                let typeName = typeID.split(separator: ".").map { $0.capitalized }.joined()
                    .replacingOccurrences(of: "#", with: ".")

                registrations.append("""
                    decoders["\(typeID)"] = { decoder in
                        let obj = try \(typeName)(from: decoder)
                        return .knownType(obj)
                    }
                """)
            }
        }

        let content = """
        import Foundation

        // Auto-generated type registry

        public indirect enum ATProtocolValueContainer: ATProtocolCodable {
            case knownType(any ATProtocolValue)
            case string(String)
            case number(Int)
            case object([String: ATProtocolValueContainer])
            case array([ATProtocolValueContainer])
            case bool(Bool)
            case null
            case link(ATProtoLink)
            case bytes(Bytes)
            case unknownType(String, ATProtocolValueContainer)

            struct TypeDecoderFactory {
                typealias DecoderFunction = (Decoder) throws -> ATProtocolValueContainer

                private let decoders: [String: DecoderFunction]

                init() {
                    var decoders: [String: DecoderFunction] = [:]

        \(registrations.joined(separator: "\n\n"))

                    self.decoders = decoders
                }

                func decode(typeIdentifier: String, from decoder: Decoder) throws -> ATProtocolValueContainer {
                    if let decoderFunc = decoders[typeIdentifier] {
                        return try decoderFunc(decoder)
                    }
                    // Unknown type - decode as generic container
                    let container = try ATProtocolValueContainer(from: decoder)
                    return .unknownType(typeIdentifier, container)
                }
            }
        }
        """

        let filePath = (outputPath as NSString).appendingPathComponent("ATProtocolValueContainer.swift")
        try content.write(toFile: filePath, atomically: true, encoding: .utf8)
    }
}
