import Foundation
import ArgumentParser

@main
struct SwiftGeneratorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swift-generator",
        abstract: "Generate Swift code from ATProtocol Lexicon files",
        version: "1.0.0"
    )

    @Argument(help: "Path to the lexicons directory")
    var lexiconsPath: String

    @Argument(help: "Path to the output directory")
    var outputPath: String

    @Flag(name: .shortAndLong, help: "Enable verbose output")
    var verbose: Bool = false

    func run() async throws {
        print("SwiftGenerator v1.0.0")
        print("=====================\n")

        // Validate paths
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: lexiconsPath) else {
            throw ValidationError("Lexicons path does not exist: \(lexiconsPath)")
        }

        // Create coordinator and run generation
        let coordinator = GeneratorCoordinator(
            lexiconsPath: lexiconsPath,
            outputPath: outputPath
        )

        try await coordinator.generate()

        print("\n🎉 Generation completed successfully!")
    }
}
